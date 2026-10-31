import logging
import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.models import Alert, AuditLog, CallAttempt, Patient, Person, Reminder, ReminderLog
from app.db.mongo import mongo_manager
from app.db.session import SessionLocal
from app.modules.alerts.service import notify_caregivers
from app.modules.calls.omnidim_service import CallStatus, OmniDimDispatchResult, omnidim_service

logger = logging.getLogger(__name__)

MAX_CONSECUTIVE_UNANSWERED_ATTEMPTS = 3


class CallOrchestrationResult:
    def __init__(
        self,
        call_session_id: str,
        attempt_number: int,
        status: CallStatus,
        provider_call_id: Optional[str] = None,
        is_escalated: bool = False,
        alert_id: Optional[int] = None,
        recipient_phone: Optional[str] = None,
        recipient_name: Optional[str] = None,
        message: str = "",
        dispatch_result: Optional[OmniDimDispatchResult] = None,
    ):
        self.call_session_id = call_session_id
        self.attempt_number = attempt_number
        self.status = status
        self.provider_call_id = provider_call_id
        self.is_escalated = is_escalated
        self.alert_id = alert_id
        self.recipient_phone = recipient_phone
        self.recipient_name = recipient_name
        self.message = message
        self.dispatch_result = dispatch_result

    def to_dict(self) -> Dict[str, Any]:
        return {
            "call_session_id": self.call_session_id,
            "attempt_number": self.attempt_number,
            "status": self.status.value,
            "provider_call_id": self.provider_call_id,
            "is_escalated": self.is_escalated,
            "alert_id": self.alert_id,
            "recipient_phone": self.recipient_phone,
            "recipient_name": self.recipient_name,
            "message": self.message,
        }


class CallOrchestrator:
    """
    Backend-controlled call lifecycle manager:
    - Governs 3-attempt calling lifecycle (Attempt 1 -> 2 -> 3 -> Caretaker alert).
    - Distinguishes patient no-answer vs technical provider failure.
    - Resets failure counter upon answer.
    - Bridges OmniDimension calls to SQLite & MongoDB.
    """

    def get_consecutive_unanswered_attempts(
        self,
        call_session_id: str,
        db: Session,
    ) -> List[CallAttempt]:
        """
        Retrieves consecutive unanswered call attempts for this session.
        If any attempt was answered, consecutive failures reset to 0.
        """
        attempts = (
            db.query(CallAttempt)
            .filter(CallAttempt.call_session_id == call_session_id)
            .order_by(CallAttempt.attempt_number.asc())
            .all()
        )

        unanswered: List[CallAttempt] = []
        for att in attempts:
            if att.status == CallStatus.ANSWERED.value:
                # Reset consecutive failure count if any attempt was answered
                unanswered.clear()
            elif att.status in (
                CallStatus.NO_ANSWER.value,
                CallStatus.BUSY.value,
                CallStatus.VOICEMAIL.value,
            ):
                unanswered.append(att)
            # Note: Technical failures (att.is_technical_failure) do not increment unanswered count

        return unanswered

    async def initiate_call(
        self,
        patient_id: int,
        reason: str,
        source: str = "routine",
        call_session_id: Optional[str] = None,
        reminder_id: Optional[int] = None,
        contact_id: Optional[int] = None,
        db: Optional[Session] = None,
    ) -> CallOrchestrationResult:
        """
        Initiates a backend-controlled call attempt (max 3 consecutive attempts).
        """
        close_db = False
        if db is None:
            db = SessionLocal()
            close_db = True

        try:
            sess_id = call_session_id or f"sess_{uuid.uuid4().hex[:12]}"

            # 1. Check existing consecutive unanswered attempts
            unanswered = self.get_consecutive_unanswered_attempts(sess_id, db)
            unanswered_count = len(unanswered)

            if unanswered_count >= MAX_CONSECUTIVE_UNANSWERED_ATTEMPTS:
                # Max 3 attempts already exhausted: trigger escalation, do not call again
                logger.warning(
                    f"Session {sess_id}: Already reached {unanswered_count} unanswered attempts. Escalating."
                )
                alert = await self.handle_three_consecutive_unanswered_calls(
                    patient_id=patient_id,
                    reason=reason,
                    session_id=sess_id,
                    reminder_id=reminder_id,
                    db=db,
                )
                return CallOrchestrationResult(
                    call_session_id=sess_id,
                    attempt_number=unanswered_count,
                    status=CallStatus.FAILED,
                    is_escalated=True,
                    alert_id=alert.id,
                    message=f"Maximum {MAX_CONSECUTIVE_UNANSWERED_ATTEMPTS} attempts already reached. Caretaker alerted.",
                )

            # Check if an active attempt is already in flight for this session
            active_attempt = (
                db.query(CallAttempt)
                .filter(
                    CallAttempt.call_session_id == sess_id,
                    CallAttempt.status.in_([CallStatus.INITIATED.value, CallStatus.RINGING.value]),
                )
                .first()
            )
            if active_attempt:
                logger.warning(
                    f"Session {sess_id} already has call attempt #{active_attempt.attempt_number} in flight. Returning existing attempt."
                )
                return CallOrchestrationResult(
                    call_session_id=sess_id,
                    attempt_number=active_attempt.attempt_number,
                    status=CallStatus(active_attempt.status),
                    provider_call_id=active_attempt.provider_call_id,
                    recipient_phone=active_attempt.recipient_phone,
                    recipient_name=active_attempt.recipient_name,
                    message=f"Attempt {active_attempt.attempt_number} is already in flight.",
                )

            current_attempt_num = unanswered_count + 1

            # 2. Resolve recipient contact
            patient = db.query(Patient).filter(Patient.id == patient_id).first()
            patient_name = patient.name if patient else "Patient"

            target_contact: Optional[Person] = None
            if contact_id:
                target_contact = db.query(Person).filter(Person.id == contact_id).first()

            if not target_contact:
                # Find primary emergency contact
                target_contact = (
                    db.query(Person)
                    .filter(Person.patient_id == patient_id, Person.is_emergency_contact == True)
                    .order_by(Person.priority.asc(), Person.id.asc())
                    .first()
                )

            if not target_contact:
                target_contact = (
                    db.query(Person)
                    .filter(Person.patient_id == patient_id)
                    .order_by(Person.id.asc())
                    .first()
                )

            recipient_phone = target_contact.phone if target_contact and target_contact.phone else settings.CAREGIVER_PHONE
            recipient_name = target_contact.name if target_contact else "Primary Caregiver"

            # 3. Dispatch to OmniDim
            metadata = {
                "patient_id": patient_id,
                "session_id": sess_id,
                "attempt_number": current_attempt_num,
                "reminder_id": reminder_id,
                "source": source,
            }
            context = {
                "patient_name": patient_name,
                "recipient_name": recipient_name,
                "reason": reason,
                "attempt_number": current_attempt_num,
            }

            dispatch = await omnidim_service.dispatch_call(
                to_number=recipient_phone,
                recipient_name=recipient_name,
                patient_name=patient_name,
                reason=reason,
                call_context=context,
                metadata=metadata,
            )

            # 4. Record CallAttempt in SQLite
            now_dt = datetime.utcnow()
            attempt = CallAttempt(
                call_session_id=sess_id,
                patient_id=patient_id,
                person_id=target_contact.id if target_contact else None,
                reminder_id=reminder_id,
                attempt_number=current_attempt_num,
                provider="omnidim",
                provider_call_id=dispatch.provider_call_id,
                recipient_phone=recipient_phone,
                recipient_name=recipient_name,
                status=dispatch.status.value,
                is_technical_failure=dispatch.is_technical_failure,
                failure_reason=dispatch.failure_reason,
                created_at=now_dt,
                updated_at=now_dt,
            )
            db.add(attempt)

            # Audit log
            audit = AuditLog(
                patient_id=patient_id,
                action="call_attempt_initiated",
                details=(
                    f"Session {sess_id} (Attempt {current_attempt_num}/{MAX_CONSECUTIVE_UNANSWERED_ATTEMPTS}) "
                    f"to {recipient_name} ({recipient_phone}) via OmniDim: status={dispatch.status.value}"
                ),
                timestamp=now_dt,
            )
            db.add(audit)
            db.commit()
            db.refresh(attempt)

            # 5. Mirror in MongoDB calls collection
            call_doc = {
                "id": dispatch.provider_call_id or f"att_{attempt.id}",
                "call_session_id": sess_id,
                "attempt_number": current_attempt_num,
                "patient_id": patient_id,
                "recipient": {"name": recipient_name, "phone": recipient_phone},
                "provider": "omnidim",
                "provider_call_id": dispatch.provider_call_id,
                "status": dispatch.status.value,
                "reason": reason,
                "source": source,
                "reminder_id": reminder_id,
                "is_technical_failure": dispatch.is_technical_failure,
                "created_at": now_dt.isoformat(),
                "updated_at": now_dt.isoformat(),
            }
            try:
                calls_coll = mongo_manager.get_collection("calls")
                await calls_coll.insert_one(call_doc)
            except Exception as e:
                logger.warning(f"Failed to record call in MongoDB: {e}")

            return CallOrchestrationResult(
                call_session_id=sess_id,
                attempt_number=current_attempt_num,
                status=dispatch.status,
                provider_call_id=dispatch.provider_call_id,
                is_escalated=False,
                recipient_phone=recipient_phone,
                recipient_name=recipient_name,
                message=f"Attempt {current_attempt_num} initiated successfully via OmniDim.",
                dispatch_result=dispatch,
            )
        finally:
            if close_db:
                db.close()

    async def handle_call_result(
        self,
        provider_call_id: str,
        provider_status: str,
        raw_payload: Optional[Dict[str, Any]] = None,
        duration_seconds: int = 0,
        failure_reason: Optional[str] = None,
        db: Optional[Session] = None,
    ) -> Dict[str, Any]:
        """
        Processes OmniDim call outcome / webhook result:
        - Updates call attempt status.
        - Resets failure counter if answered.
        - Triggers next attempt if unanswered (< 3).
        - Escalates to caretaker if 3 consecutive attempts unanswered.
        - Distinguishes technical failure vs patient no-answer.
        """
        close_db = False
        if db is None:
            db = SessionLocal()
            close_db = True

        try:
            norm_status = omnidim_service.normalize_status(provider_status)
            payload = raw_payload or {}
            now_dt = datetime.utcnow()

            # 1. Match by provider_call_id
            attempt = None
            if provider_call_id:
                attempt = (
                    db.query(CallAttempt)
                    .filter(CallAttempt.provider_call_id == str(provider_call_id))
                    .first()
                )

            # 2. Fallback lookup by metadata session_id + attempt_number
            meta = payload.get("metadata") or {}
            if not attempt and meta.get("session_id") and meta.get("attempt_number"):
                attempt = (
                    db.query(CallAttempt)
                    .filter(
                        CallAttempt.call_session_id == str(meta["session_id"]),
                        CallAttempt.attempt_number == int(meta["attempt_number"]),
                    )
                    .first()
                )

            # 3. Fallback lookup by session_id alone
            if not attempt and meta.get("session_id"):
                attempt = (
                    db.query(CallAttempt)
                    .filter(CallAttempt.call_session_id == str(meta["session_id"]))
                    .order_by(CallAttempt.attempt_number.desc())
                    .first()
                )

            # 4. Fallback lookup by reminder_id alone
            if not attempt and meta.get("reminder_id"):
                attempt = (
                    db.query(CallAttempt)
                    .filter(CallAttempt.reminder_id == int(meta["reminder_id"]))
                    .order_by(CallAttempt.attempt_number.desc())
                    .first()
                )

            if not attempt:
                logger.warning(f"No existing CallAttempt found for provider_call_id={provider_call_id}")
                return {
                    "status": "not_found",
                    "provider_call_id": provider_call_id,
                    "normalized_status": norm_status.value,
                    "message": "Call attempt record not found.",
                }

            # -----------------------------------------------------------------
            # Idempotency / Duplicate Webhook Check:
            # -----------------------------------------------------------------
            if attempt.status in (
                CallStatus.ANSWERED.value,
                CallStatus.NO_ANSWER.value,
                CallStatus.BUSY.value,
                CallStatus.VOICEMAIL.value,
            ):
                logger.info(
                    f"Session {attempt.call_session_id} attempt {attempt.attempt_number} already finalized as '{attempt.status}'. "
                    f"Skipping duplicate webhook processing."
                )
                return {
                    "status": attempt.status,
                    "call_session_id": attempt.call_session_id,
                    "attempt_number": attempt.attempt_number,
                    "action": "already_processed",
                    "message": f"Webhook already processed for attempt {attempt.attempt_number} (status={attempt.status}).",
                }

            # Also check if next attempt has already been initiated for this session
            existing_next = (
                db.query(CallAttempt)
                .filter(
                    CallAttempt.call_session_id == attempt.call_session_id,
                    CallAttempt.attempt_number > attempt.attempt_number,
                )
                .first()
            )
            if existing_next:
                logger.info(
                    f"Session {attempt.call_session_id} attempt {attempt.attempt_number}: next attempt #{existing_next.attempt_number} already initiated. Skipping duplicate."
                )
                return {
                    "status": attempt.status,
                    "call_session_id": attempt.call_session_id,
                    "attempt_number": attempt.attempt_number,
                    "action": "already_processed",
                    "message": f"Next attempt already initiated for session {attempt.call_session_id}.",
                }

            # Check if this is a technical provider failure
            is_tech_fail = (norm_status == CallStatus.FAILED) or bool(payload.get("error"))
            resolved_failure_reason = failure_reason or payload.get("error") or (
                "Technical provider error" if is_tech_fail else None
            )

            attempt.status = norm_status.value
            attempt.duration_seconds = duration_seconds or payload.get("duration_seconds", 0)
            attempt.is_technical_failure = is_tech_fail
            if resolved_failure_reason:
                attempt.failure_reason = resolved_failure_reason
            attempt.updated_at = now_dt
            db.commit()

            # Update MongoDB
            try:
                calls_coll = mongo_manager.get_collection("calls")
                await calls_coll.update_one(
                    {"provider_call_id": provider_call_id},
                    {
                        "$set": {
                            "status": norm_status.value,
                            "duration_seconds": attempt.duration_seconds,
                            "is_technical_failure": is_tech_fail,
                            "failure_reason": resolved_failure_reason,
                            "updated_at": now_dt.isoformat(),
                        }
                    },
                )
            except Exception as e:
                logger.warning(f"Failed to update MongoDB call status: {e}")

            # -----------------------------------------------------------------
            # Outcome Case 1: Call Answered / Completed
            # -----------------------------------------------------------------
            if norm_status == CallStatus.ANSWERED:
                # Update linked reminder if present
                if attempt.reminder_id:
                    rem = db.query(Reminder).filter(Reminder.id == attempt.reminder_id).first()
                    if rem:
                        rem.status = "acknowledged"
                        rem.retry_count = 0
                        log_ack = ReminderLog(
                            patient_id=rem.patient_id,
                            reminder_id=rem.id,
                            action="acknowledged",
                            outcome="acknowledged",
                            details=f"Call completed and acknowledged via OmniDim (attempt {attempt.attempt_number}).",
                            timestamp=now_dt,
                        )
                        db.add(log_ack)

                audit = AuditLog(
                    patient_id=attempt.patient_id,
                    action="call_answered",
                    details=(
                        f"Call session {attempt.call_session_id} (Attempt {attempt.attempt_number}) was ANSWERED/COMPLETED. "
                        f"Consecutive failure state reset."
                    ),
                    timestamp=now_dt,
                )
                db.add(audit)
                db.commit()
                return {
                    "status": "answered",
                    "call_session_id": attempt.call_session_id,
                    "attempt_number": attempt.attempt_number,
                    "action": "completed",
                    "message": f"Call attempt {attempt.attempt_number} completed successfully. Consecutive failure state reset.",
                }

            # -----------------------------------------------------------------
            # Outcome Case 2: Technical Failure (NOT patient's fault)
            # -----------------------------------------------------------------
            if is_tech_fail:
                logger.warning(
                    f"Session {attempt.call_session_id} attempt {attempt.attempt_number} failed technically: "
                    f"{resolved_failure_reason}. Not incrementing unanswered streak."
                )
                audit = AuditLog(
                    patient_id=attempt.patient_id,
                    action="call_technical_failure",
                    details=(
                        f"Session {attempt.call_session_id} attempt {attempt.attempt_number} technical failure: "
                        f"{resolved_failure_reason}"
                    ),
                    timestamp=now_dt,
                )
                db.add(audit)
                db.commit()
                return {
                    "status": "technical_failure",
                    "call_session_id": attempt.call_session_id,
                    "attempt_number": attempt.attempt_number,
                    "action": "logged_error",
                    "failure_reason": resolved_failure_reason,
                    "message": "Technical provider failure recorded without penalizing patient response streak.",
                }

            # -----------------------------------------------------------------
            # Outcome Case 3: Genuine Unanswered (no_answer, busy, voicemail)
            # -----------------------------------------------------------------
            if norm_status in (CallStatus.NO_ANSWER, CallStatus.BUSY, CallStatus.VOICEMAIL):
                if attempt.attempt_number < MAX_CONSECUTIVE_UNANSWERED_ATTEMPTS:
                    next_attempt_num = attempt.attempt_number + 1

                    # Update reminder retry_count if linked
                    if attempt.reminder_id:
                        rem = db.query(Reminder).filter(Reminder.id == attempt.reminder_id).first()
                        if rem:
                            rem.retry_count = attempt.attempt_number
                            log_rep = ReminderLog(
                                patient_id=rem.patient_id,
                                reminder_id=rem.id,
                                action="unanswered_call",
                                outcome="repeated",
                                details=f"Call attempt {attempt.attempt_number} unanswered via OmniDim. Next attempt scheduled.",
                                timestamp=now_dt,
                            )
                            db.add(log_rep)
                            db.commit()

                    logger.info(
                        f"Session {attempt.call_session_id}: Attempt {attempt.attempt_number} unanswered ({norm_status.value}). "
                        f"Triggering next attempt {next_attempt_num}/{MAX_CONSECUTIVE_UNANSWERED_ATTEMPTS}."
                    )
                    # Automatically initiate the next attempt in the 3-attempt sequence
                    next_res = await self.initiate_call(
                        patient_id=attempt.patient_id,
                        reason=f"Follow-up attempt {next_attempt_num} after no answer ({norm_status.value})",
                        source="retry_unanswered",
                        call_session_id=attempt.call_session_id,
                        reminder_id=attempt.reminder_id,
                        contact_id=attempt.person_id,
                        db=db,
                    )
                    return {
                        "status": norm_status.value,
                        "call_session_id": attempt.call_session_id,
                        "attempt_number": attempt.attempt_number,
                        "action": "next_attempt_initiated",
                        "next_attempt_number": next_attempt_num,
                        "next_call_result": next_res.to_dict(),
                        "message": f"Attempt {attempt.attempt_number} was unanswered. Attempt {next_attempt_num} initiated.",
                    }
                else:
                    # Attempt 3 failed -> Reached 3 consecutive unanswered attempts!
                    logger.warning(
                        f"Session {attempt.call_session_id}: Attempt 3 unanswered. Escalating to caretaker."
                    )
                    alert = await self.handle_three_consecutive_unanswered_calls(
                        patient_id=attempt.patient_id,
                        reason="Patient did not answer after 3 consecutive attempts",
                        session_id=attempt.call_session_id,
                        reminder_id=attempt.reminder_id,
                        db=db,
                    )
                    return {
                        "status": norm_status.value,
                        "call_session_id": attempt.call_session_id,
                        "attempt_number": attempt.attempt_number,
                        "action": "escalated_to_caretaker",
                        "alert_id": alert.id,
                        "message": "3 consecutive unanswered calls reached. Escalated to caretaker.",
                    }

            return {
                "status": norm_status.value,
                "call_session_id": attempt.call_session_id,
                "attempt_number": attempt.attempt_number,
                "action": "recorded",
                "message": f"Call marked as {norm_status.value}.",
            }
        finally:
            if close_db:
                db.close()

    async def handle_three_consecutive_unanswered_calls(
        self,
        patient_id: int,
        reason: str,
        session_id: str,
        reminder_id: Optional[int] = None,
        db: Optional[Session] = None,
    ) -> Alert:
        """
        Escalation Point: Called when 3 consecutive call attempts have gone unanswered.
        Creates an urgent caretaker alert record in SQLite, MongoDB, and AuditLog
        via the existing caretaker alert mechanism (notify_caregivers).
        """
        close_db = False
        if db is None:
            db = SessionLocal()
            close_db = True

        try:
            patient = db.query(Patient).filter(Patient.id == patient_id).first()
            patient_name = patient.name if patient else "Patient"
            now_dt = datetime.utcnow()

            msg = (
                f"🚨 [URGENT ESCALATION] Patient {patient_name} did not answer 3 consecutive calls. "
                f"Reason: {reason}. Immediate caretaker check-in requested. (Session: {session_id})"
            )

            # Update reminder if linked
            if reminder_id:
                rem = db.query(Reminder).filter(Reminder.id == reminder_id).first()
                if rem:
                    rem.status = "escalated"
                    rem.retry_count = MAX_CONSECUTIVE_UNANSWERED_ATTEMPTS
                    log_esc = ReminderLog(
                        patient_id=rem.patient_id,
                        reminder_id=rem.id,
                        action="escalated",
                        outcome="escalated",
                        details="Patient did not answer 3 consecutive calls; escalated to caretaker.",
                        timestamp=now_dt,
                    )
                    db.add(log_esc)

            # Trigger the existing caretaker alert mechanism
            alert = notify_caregivers(
                patient_id=patient_id,
                alert_type="calling_escalation",
                message=msg,
                reminder_id=reminder_id,
                db=db,
            )

            # Record in MongoDB alerts collection
            try:
                alerts_coll = mongo_manager.get_collection("alerts")
                await alerts_coll.insert_one({
                    "patient_id": patient_id,
                    "alert_id": alert.id,
                    "type": "calling_escalation",
                    "severity": "critical",
                    "message": msg,
                    "session_id": session_id,
                    "created_at": now_dt.isoformat(),
                })
            except Exception as e:
                logger.warning(f"Failed to write escalation alert to MongoDB: {e}")

            logger.critical(f"Caregiver escalation alert #{alert.id} generated for patient {patient_id}: {msg}")
            return alert
        finally:
            if close_db:
                db.close()


call_orchestrator = CallOrchestrator()

