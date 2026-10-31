import logging
import re
import uuid
from enum import Enum
from typing import Any, Dict, Optional
import httpx
from pydantic import BaseModel

from app.core.config import settings

logger = logging.getLogger(__name__)


class CallStatus(str, Enum):
    INITIATED = "initiated"
    RINGING = "ringing"
    ANSWERED = "answered"
    NO_ANSWER = "no_answer"
    FAILED = "failed"
    BUSY = "busy"
    VOICEMAIL = "voicemail"
    CANCELLED = "cancelled"


class OmniDimDispatchResult(BaseModel):
    success: bool
    provider_call_id: Optional[str] = None
    status: CallStatus
    is_technical_failure: bool = False
    failure_reason: Optional[str] = None
    raw_response: Dict[str, Any] = {}


class OmniDimService:
    """
    Client for OmniDimension (OmniDim) Outbound Voice Calling API.
    Handles call dispatch, post-call webhook normalization, and error isolation.
    """

    @staticmethod
    def normalize_status(provider_status: Optional[str]) -> CallStatus:
        """
        Normalizes provider-specific call status to standard CallStatus enum.
        """
        if not provider_status:
            return CallStatus.INITIATED

        norm = provider_status.lower().strip().replace("-", "_")

        if norm in ("completed", "answered", "in_progress", "connected", "human_answered"):
            return CallStatus.ANSWERED
        elif norm in ("no_answer", "unanswered", "timeout", "missed"):
            return CallStatus.NO_ANSWER
        elif norm in ("busy", "line_busy"):
            return CallStatus.BUSY
        elif norm in ("voicemail", "voicemail_detected", "machine_detected", "answering_machine"):
            return CallStatus.VOICEMAIL
        elif norm in ("cancelled", "canceled"):
            return CallStatus.CANCELLED
        elif norm in ("ringing", "in_call_ringing"):
            return CallStatus.RINGING
        elif norm in ("failed", "error", "rejected", "undelivered"):
            return CallStatus.FAILED
        elif norm in ("initiated", "queued", "created", "dispatched"):
            return CallStatus.INITIATED

        return CallStatus.FAILED

    @staticmethod
    def normalize_phone_number(phone: Optional[str]) -> str:
        """
        Normalizes a phone number to E.164 format for outbound calls:
        - If the number already starts with '+', leave it unchanged.
        - If it is a 10-digit Indian number, prepend '+91'.
        """
        if not phone:
            return ""
        cleaned = phone.strip()
        if cleaned.startswith("+"):
            return cleaned
        digits = re.sub(r"\D", "", cleaned)
        if len(digits) == 10:
            return f"+91{digits}"
        return cleaned

    @staticmethod
    def is_configured() -> bool:
        """Checks if OmniDim API key is present in environment."""
        return bool(settings.OMNIDIM_API_KEY and settings.OMNIDIM_API_KEY.strip())

    async def dispatch_call(
        self,
        to_number: str,
        recipient_name: Optional[str] = None,
        patient_name: Optional[str] = None,
        reason: Optional[str] = None,
        call_context: Optional[Dict[str, Any]] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> OmniDimDispatchResult:
        """
        Initiates an outbound phone call via OmniDimension API.
        Safe stub if credentials are not configured.
        """
        if not to_number:
            return OmniDimDispatchResult(
                success=False,
                provider_call_id=None,
                status=CallStatus.FAILED,
                is_technical_failure=True,
                failure_reason="Recipient phone number is required.",
            )

        norm_to_number = self.normalize_phone_number(to_number)

        # 1. Unconfigured safe stub mode (never commits secrets or crashes)
        if not self.is_configured():
            stub_id = f"omnidim_stub_{uuid.uuid4().hex[:12]}"
            logger.info(
                f"[OmniDim Service STUB] Dispatching call to {norm_to_number} (recipient: {recipient_name or 'Unknown'}). "
                f"OMNIDIM_API_KEY is not configured; simulated provider call ID: {stub_id}"
            )
            return OmniDimDispatchResult(
                success=True,
                provider_call_id=stub_id,
                status=CallStatus.INITIATED,
                is_technical_failure=False,
                failure_reason=None,
                raw_response={
                    "mode": "unconfigured_stub",
                    "to_number": norm_to_number,
                    "simulated_call_id": stub_id,
                },
            )

        # 2. Live OmniDim API Request
        base_url = settings.OMNIDIM_BASE_URL.rstrip("/")
        url = f"{base_url}/calls/dispatch"
        headers = {
            "Authorization": f"Bearer {settings.OMNIDIM_API_KEY}",
            "Content-Type": "application/json",
        }

        ctx = call_context or {}
        if recipient_name and "recipient_name" not in ctx:
            ctx["recipient_name"] = recipient_name
        if patient_name and "patient_name" not in ctx:
            ctx["patient_name"] = patient_name
        if reason and "reason" not in ctx:
            ctx["reason"] = reason

        meta = metadata or {}

        payload: Dict[str, Any] = {
            "to_number": norm_to_number,
            "call_context": ctx,
            "metadata": meta,
        }

        if settings.OMNIDIM_AGENT_ID:
            payload["agent_id"] = settings.OMNIDIM_AGENT_ID
        if settings.OMNIDIM_FROM_NUMBER_ID:
            payload["from_number_id"] = settings.OMNIDIM_FROM_NUMBER_ID

        if settings.OMNIDIM_WEBHOOK_URL:
            payload["__post_call_actions"] = {
                "webhook": {
                    "url": settings.OMNIDIM_WEBHOOK_URL,
                    "trigger_call_statuses": [
                        "completed",
                        "no_answer",
                    ],
                }
            }

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.post(url, json=payload, headers=headers)

                if response.status_code in (200, 201):
                    data = response.json()
                    call_id = data.get("call_id") or data.get("id") or str(uuid.uuid4())
                    raw_status = data.get("status", "initiated")
                    norm_status = self.normalize_status(raw_status)
                    logger.info(f"OmniDim call dispatched successfully: call_id={call_id}, status={norm_status}")
                    return OmniDimDispatchResult(
                        success=True,
                        provider_call_id=str(call_id),
                        status=norm_status,
                        is_technical_failure=False,
                        raw_response=data,
                    )
                else:
                    err_msg = f"OmniDim API error HTTP {response.status_code}: {response.text[:200]}"
                    logger.warning(err_msg)
                    return OmniDimDispatchResult(
                        success=False,
                        provider_call_id=None,
                        status=CallStatus.FAILED,
                        is_technical_failure=True,
                        failure_reason=err_msg,
                        raw_response={"status_code": response.status_code, "error": response.text[:500]},
                    )
        except Exception as e:
            err_msg = f"OmniDim connection error: {str(e)}"
            logger.error(err_msg)
            return OmniDimDispatchResult(
                success=False,
                provider_call_id=None,
                status=CallStatus.FAILED,
                is_technical_failure=True,
                failure_reason=err_msg,
                raw_response={"exception": str(e)},
            )


omnidim_service = OmniDimService()

