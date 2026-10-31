import logging
from typing import Any, Dict, Optional
from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.modules.calls.orchestrator import call_orchestrator

logger = logging.getLogger(__name__)

router = APIRouter()


class OmniDimPostCallPayload(BaseModel):
    call_id: Optional[Any] = None
    call_status: Optional[str] = None
    status: Optional[str] = None
    bot_id: Optional[Any] = None
    bot_name: Optional[str] = None
    phone_number: Optional[str] = None
    to_number: Optional[str] = None
    call_date: Optional[str] = None
    call_duration: Optional[Any] = None
    recording_url: Optional[Any] = None
    metadata: Optional[Dict[str, Any]] = None
    call_report: Optional[Dict[str, Any]] = None

    model_config = ConfigDict(extra="allow")


@router.post("/omnidim/post-call", status_code=status.HTTP_200_OK)
async def omnidim_post_call_webhook(
    payload: OmniDimPostCallPayload,
    db: Session = Depends(get_db),
):
    """
    OmniDimension (OmniDim) Post-Call Webhook Endpoint.
    Receives post-call payload, governs 3-consecutive-no-answer workflow,
    updates call attempts and reminders, and triggers caretaker escalation on 3rd no-answer.
    """
    # Extract call_status (or fallback to status if provided)
    raw_status = payload.call_status or payload.status
    call_status = raw_status.strip().lower() if raw_status else "unknown"
    call_id = payload.call_id

    # Parse duration in seconds
    duration_seconds = 0
    if isinstance(payload.call_duration, int):
        duration_seconds = payload.call_duration
    elif isinstance(payload.call_duration, str):
        try:
            if ":" in payload.call_duration:
                parts = payload.call_duration.split(":")
                if len(parts) == 2:
                    duration_seconds = int(parts[0]) * 60 + int(parts[1])
                elif len(parts) == 3:
                    duration_seconds = int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2])
            else:
                duration_seconds = int(payload.call_duration)
        except ValueError:
            duration_seconds = 0

    # Log received payload safely
    logger.info(
        f"[OmniDim Webhook] Received post-call notification for call_id={call_id}, status='{raw_status}'"
    )

    # Process call result through backend call orchestrator
    result = await call_orchestrator.handle_call_result(
        provider_call_id=str(call_id) if call_id is not None else "",
        provider_status=raw_status or "unknown",
        raw_payload=payload.model_dump(),
        duration_seconds=duration_seconds,
        db=db,
    )

    logger.info(
        f"[OmniDim Webhook Processed] call_id={call_id}, status='{raw_status}', action={result.get('action')}"
    )

    return {
        "status": "success",
        "received": True,
        "call_id": call_id,
        "call_status": raw_status,
        "action": result.get("action", "processed"),
        "message": result.get("message", f"Webhook processed: status={raw_status}"),
        "result": result,
    }
