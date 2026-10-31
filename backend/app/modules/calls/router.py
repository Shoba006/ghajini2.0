import logging
import uuid
from datetime import datetime
from typing import Any, Dict, List, Literal, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.models import Alert, AuditLog, CallAttempt, Patient, Person, Reminder
from app.db.mongo import mongo_manager
from app.db.session import get_db
from app.modules.calls.orchestrator import call_orchestrator
from app.modules.calls.policy import check_call_policy
from app.modules.calls.telegram import send_telegram_briefing
from app.modules.llm.provider import generate_call_wording

logger = logging.getLogger(__name__)
router = APIRouter()


# -------------------------------------------------------------
# Request & Response Schemas
# -------------------------------------------------------------
class ContactInfo(BaseModel):
    id: int
    name: str
    relationship: str
    phone: str
    priority: int
    is_emergency_contact: bool = True

    model_config = ConfigDict(from_attributes=True)


class CallRequestPayload(BaseModel):
    patient_id: Optional[int] = 1
    reason: str
    source: str  # "sos", "emergency_phrase", "reminder_escalation", "missed_checkins", "call_family", "manual"
    lang: Optional[str] = "en"
    contact_index: Optional[int] = 0
    bypass_cooldown: Optional[bool] = False


class CallResponse(BaseModel):
    id: Optional[str] = None
    allowed: bool
    block_reason: Optional[str] = None
    contact: Optional[ContactInfo] = None
    contact_index: int = 0
    has_next_contact: bool = False
    next_contact: Optional[ContactInfo] = None
    patient_message: Optional[str] = None
    caregiver_briefing: Optional[str] = None
    video_room_url: Optional[str] = None
    channel_results: Dict[str, Any] = {}
    created_at: Optional[str] = None


class CallResultPayload(BaseModel):
    status: Literal["answered", "not_answered", "cancelled"]
    note: Optional[str] = None


class CallResultResponse(BaseModel):
    id: str
    status: str
    has_next_contact: bool = False
    next_contact: Optional[ContactInfo] = None
    message: str


class TestAlertPayload(BaseModel):
    patient_id: Optional[int] = 1
    bot_token: Optional[str] = None
    chat_id: Optional[str] = None
    lang: Optional[str] = "en"


class OmniDimWebhookPayload(BaseModel):
    call_id: Optional[str] = None
    id: Optional[str] = None
    status: str
    duration_seconds: Optional[int] = 0
    error: Optional[str] = None
    failure_reason: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None
    call_context: Optional[Dict[str, Any]] = None

    model_config = ConfigDict(extra="allow")


class OrchestratedCallRequest(BaseModel):
    patient_id: Optional[int] = 1
    reason: str
    source: Optional[str] = "routine"
    call_session_id: Optional[str] = None
    reminder_id: Optional[int] = None
    contact_id: Optional[int] = None


# -------------------------------------------------------------
# Call Endpoints
# -------------------------------------------------------------
@router.post("/request", response_model=CallResponse)
async def request_call(
    payload: CallRequestPayload,
    db: Session = Depends(get_db),
):
    """
    1. Checks deterministic policy rules (limits, cooldown, quiet hours).
    2. Resolves emergency contact by priority.
    3. Generates free wording (Ollama / OpenRouter with template fallback).
    4. Dispatches caregiver briefing via Telegram (non-blocking).
    5. Saves call record and audit log in MongoDB & SQLite.
    """
    pid = payload.patient_id or settings.DEFAULT_PATIENT_ID
    now_dt = datetime.utcnow()
    now_iso = now_dt.isoformat()

    # 1. Policy Decision
    allowed, block_reason, primary_contact, all_contacts = await check_call_policy(
        patient_id=pid,
        reason=payload.reason,
        source=payload.source,
        db=db,
        bypass_cooldown=bool(payload.bypass_cooldown),
    )

    if not allowed or not primary_contact:
        # Log blocked attempt
        call_id = f"call_{uuid.uuid4().hex[:10]}"
        calls_coll = mongo_manager.get_collection("calls")
        try:
            await calls_coll.insert_one({
                "id": call_id,
                "patient_id": pid,
                "reason": payload.reason,
                "source": payload.source,
                "allowed": False,
                "block_reason": block_reason,
                "created_at": now_iso,
            })
        except Exception:
            pass

        return CallResponse(
            id=call_id,
            allowed=False,
            block_reason=block_reason or "Call attempt not permitted by safety rules.",
            contact=None,
            channel_results={},
            created_at=now_iso,
        )

    # 2. Pick target contact based on contact_index
    idx = payload.contact_index or 0
    if idx < len(all_contacts):
        target_contact = all_contacts[idx]
    else:
        target_contact = primary_contact
        idx = 0

    has_next = (idx + 1) < len(all_contacts)
    next_c = all_contacts[idx + 1] if has_next else None

    # Retrieve patient name and last reminder info
    patient = db.query(Patient).filter(Patient.id == pid).first()
    patient_name = patient.name if patient else "Patient"

    last_rem = (
        db.query(Reminder)
        .filter(Reminder.patient_id == pid)
        .order_by(Reminder.last_triggered_at.desc())
        .first()
    )
    last_reminder_text = f"{last_rem.title} ({last_rem.scheduled_time})" if last_rem else None
    pressed_help = "sos" in payload.source.lower() or "help" in payload.reason.lower()

    # 3. Generate Wording with Free AI Model
    time_str = datetime.now().strftime("%I:%M %p")
    patient_msg, briefing = await generate_call_wording(
        patient_name=patient_name,
        caregiver_name=target_contact.name,
        reason=payload.reason,
        time_str=time_str,
        last_reminder=last_reminder_text,
        pressed_help=pressed_help,
        lang=payload.lang or "en",
    )

    # 4. Optional Video Room URL
    video_url = None
    if settings.VIDEO_LINK_BASE_URL:
        base = settings.VIDEO_LINK_BASE_URL.rstrip("/")
        video_url = f"{base}/ghajini-{pid}-{uuid.uuid4().hex[:6]}"

    # 5. Caregiver Briefing Channel (Free Telegram Bot)
    tg_success, tg_detail = await send_telegram_briefing(
        briefing_text=briefing,
        video_room_url=video_url,
    )
    channel_results = {"telegram": tg_detail}

    # 6. Persist Alert in SQLite & MongoDB
    alert = Alert(
        patient_id=pid,
        alert_type="calling_agent",
        message=f"Call triggered to {target_contact.name} ({target_contact.phone}): {payload.reason}",
        status="sent",
        created_at=now_dt,
    )
    db.add(alert)

    call_id = f"call_{uuid.uuid4().hex[:10]}"
    audit = AuditLog(
        patient_id=pid,
        action="call_request",
        details=f"[{payload.source}] Placed call {call_id} to {target_contact.name} ({target_contact.phone}) - Reason: {payload.reason}",
        timestamp=now_dt,
    )
    db.add(audit)
    db.commit()

    # Save in MongoDB `calls` and `alerts`
    call_doc = {
        "id": call_id,
        "patient_id": pid,
        "reason": payload.reason,
        "source": payload.source,
        "allowed": True,
        "contact": {
            "id": target_contact.id,
            "name": target_contact.name,
            "phone": target_contact.phone or settings.CAREGIVER_PHONE,
            "relationship": target_contact.relationship,
            "priority": target_contact.priority,
        },
        "contact_index": idx,
        "patient_message": patient_msg,
        "caregiver_briefing": briefing,
        "video_room_url": video_url,
        "channel_results": channel_results,
        "status": "initiated",
        "created_at": now_iso,
        "updated_at": now_iso,
    }
    try:
        calls_coll = mongo_manager.get_collection("calls")
        await calls_coll.insert_one(call_doc)

        alerts_coll = mongo_manager.get_collection("alerts")
        await alerts_coll.insert_one({
            "patient_id": pid,
            "type": "calling_agent",
            "message": briefing,
            "contact": target_contact.name,
            "created_at": now_iso,
        })
    except Exception as e:
        logger.warning(f"Error persisting call to MongoDB: {e}")

    return CallResponse(
        id=call_id,
        allowed=True,
        block_reason=None,
        contact=ContactInfo(
            id=target_contact.id,
            name=target_contact.name,
            phone=target_contact.phone or settings.CAREGIVER_PHONE,
            relationship=target_contact.relationship,
            priority=target_contact.priority,
        ),
        contact_index=idx,
        has_next_contact=has_next,
        next_contact=ContactInfo(
            id=next_c.id,
            name=next_c.name,
            phone=next_c.phone or settings.CAREGIVER_PHONE,
            relationship=next_c.relationship,
            priority=next_c.priority,
        ) if next_c else None,
        patient_message=patient_msg,
        caregiver_briefing=briefing,
        video_room_url=video_url,
        channel_results=channel_results,
        created_at=now_iso,
    )


@router.post("/{call_id}/result", response_model=CallResultResponse)
async def report_call_result(
    call_id: str,
    payload: CallResultPayload,
    db: Session = Depends(get_db),
):
    """
    Records call outcome: 'answered', 'not_answered', or 'cancelled'.
    If 'not_answered', looks up next priority contact to offer escalation.
    """
    now_iso = datetime.utcnow().isoformat()
    calls_coll = mongo_manager.get_collection("calls")

    existing_call = None
    try:
        existing_call = await calls_coll.find_one({"id": call_id})
    except Exception:
        pass

    pid = existing_call.get("patient_id", 1) if existing_call else 1
    current_idx = existing_call.get("contact_index", 0) if existing_call else 0

    # Update in MongoDB
    try:
        await calls_coll.update_one(
            {"id": call_id},
            {"$set": {"status": payload.status, "note": payload.note, "updated_at": now_iso}}
        )
    except Exception as e:
        logger.warning(f"Failed to update call status in MongoDB: {e}")

    # Record in AuditLog
    audit = AuditLog(
        patient_id=pid,
        action="call_result",
        details=f"Call {call_id} outcome: {payload.status}. Note: {payload.note or 'none'}",
        timestamp=datetime.utcnow(),
    )
    db.add(audit)
    db.commit()

    has_next = False
    next_contact_info = None

    if payload.status == "not_answered":
        # Check next priority contact
        contacts = (
            db.query(Person)
            .filter(Person.patient_id == pid, Person.is_emergency_contact == True)
            .order_by(Person.priority.asc(), Person.id.asc())
            .all()
        )
        next_idx = current_idx + 1
        if next_idx < len(contacts):
            has_next = True
            nc = contacts[next_idx]
            next_contact_info = ContactInfo(
                id=nc.id,
                name=nc.name,
                phone=nc.phone or settings.CAREGIVER_PHONE,
                relationship=nc.relationship,
                priority=nc.priority,
            )

    msg = f"Call marked as {payload.status}."
    if has_next and next_contact_info:
        prev_name = (
            existing_call.get("contact", {}).get("name")
            if existing_call and isinstance(existing_call.get("contact"), dict)
            else "Contact"
        )
        msg = f"{prev_name} did not answer. Next contact is {next_contact_info.name}."

    return CallResultResponse(
        id=call_id,
        status=payload.status,
        has_next_contact=has_next,
        next_contact=next_contact_info,
        message=msg,
    )


@router.post("/test-alert")
async def send_test_alert(
    payload: TestAlertPayload,
    db: Session = Depends(get_db),
):
    """
    Sends a test caregiver alert via Telegram without dialing any phone.
    Used by the Caregiver Settings screen.
    """
    pid = payload.patient_id or settings.DEFAULT_PATIENT_ID
    patient = db.query(Patient).filter(Patient.id == pid).first()
    patient_name = patient.name if patient else "Mother"

    time_str = datetime.now().strftime("%I:%M %p")
    briefing = (
        f"🧪 [Ghajini 2.0 Test Alert]\n"
        f"Caregiver alert channel test for {patient_name}.\n"
        f"Time: {time_str} | Status: All systems operational."
    )

    success, detail = await send_telegram_briefing(
        briefing_text=briefing,
        bot_token=payload.bot_token,
        chat_id=payload.chat_id,
    )

    return {
        "success": success,
        "detail": detail,
        "briefing": briefing,
    }


@router.get("/history", response_model=List[Dict[str, Any]])
async def get_call_history(
    patient_id: int = Query(default=1),
    limit: int = Query(default=20),
):
    """Returns recent call records from MongoDB for caregiver dashboard."""
    calls_coll = mongo_manager.get_collection("calls")
    try:
        cursor = calls_coll.find({"patient_id": patient_id}).sort("created_at", -1).limit(limit)
        calls = await cursor.to_list(length=limit)
        for c in calls:
            if "_id" in c:
                c["_id"] = str(c["_id"])
        return calls
    except Exception as e:
        logger.warning(f"Error reading call history: {e}")
        return []


@router.post("/reset-cooldown")
async def reset_cooldown(
    patient_id: int = Query(default=1),
):
    """
    Clears recent call records from MongoDB for the patient,
    immediately removing any active 2-minute cool-down or hourly limit lock.
    """
    try:
        calls_coll = mongo_manager.get_collection("calls")
        await calls_coll.delete_many({"patient_id": patient_id})
        return {
            "status": "success",
            "message": f"Call cool-down and throttle reset successfully for patient {patient_id}.",
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}


# -------------------------------------------------------------
# OmniDimension Orchestrated Call Endpoints
# -------------------------------------------------------------
@router.post("/webhook/omnidim")
async def omnidim_webhook_callback(
    payload: OmniDimWebhookPayload,
    db: Session = Depends(get_db),
):
    """
    Receives post-call status webhook from OmniDimension.
    Updates call state, manages 3-attempt lifecycle, and triggers caretaker escalation if needed.
    """
    call_id = payload.call_id or payload.id or (payload.metadata.get("call_id") if payload.metadata else None) or ""
    result = await call_orchestrator.handle_call_result(
        provider_call_id=call_id,
        provider_status=payload.status,
        raw_payload=payload.model_dump(),
        duration_seconds=payload.duration_seconds or 0,
        failure_reason=payload.failure_reason or payload.error,
        db=db,
    )
    return {"status": "success", "result": result}


@router.post("/orchestrated/initiate")
async def initiate_orchestrated_call(
    payload: OrchestratedCallRequest,
    db: Session = Depends(get_db),
):
    """
    Initiates an outbound phone call managed by the backend 3-attempt orchestrator via OmniDim.
    """
    result = await call_orchestrator.initiate_call(
        patient_id=payload.patient_id or settings.DEFAULT_PATIENT_ID,
        reason=payload.reason,
        source=payload.source or "routine",
        call_session_id=payload.call_session_id,
        reminder_id=payload.reminder_id,
        contact_id=payload.contact_id,
        db=db,
    )
    return result.to_dict()


@router.get("/attempts/{call_session_id}")
async def get_call_session_attempts(
    call_session_id: str,
    db: Session = Depends(get_db),
):
    """
    Returns all call attempts associated with a call session ID.
    """
    attempts = (
        db.query(CallAttempt)
        .filter(CallAttempt.call_session_id == call_session_id)
        .order_by(CallAttempt.attempt_number.asc())
        .all()
    )
    return [
        {
            "id": att.id,
            "call_session_id": att.call_session_id,
            "attempt_number": att.attempt_number,
            "provider": att.provider,
            "provider_call_id": att.provider_call_id,
            "recipient_name": att.recipient_name,
            "recipient_phone": att.recipient_phone,
            "status": att.status,
            "is_technical_failure": att.is_technical_failure,
            "failure_reason": att.failure_reason,
            "duration_seconds": att.duration_seconds,
            "created_at": att.created_at.isoformat() if att.created_at else None,
            "updated_at": att.updated_at.isoformat() if att.updated_at else None,
        }
        for att in attempts
    ]
