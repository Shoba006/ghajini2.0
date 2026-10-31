import uuid
from unittest.mock import AsyncMock, MagicMock, patch
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.models import Alert, CallAttempt, Patient, Person, Reminder
from app.db.session import SessionLocal, init_db
from app.main import app
from app.modules.calls.omnidim_service import CallStatus, OmniDimDispatchResult, omnidim_service
from app.modules.calls.orchestrator import MAX_CONSECUTIVE_UNANSWERED_ATTEMPTS, call_orchestrator
from app.modules.reminders.scheduler import trigger_reminder_call_orchestration

client = TestClient(app)


@pytest.fixture(scope="module", autouse=True)
def setup_omnidim_test_data():
    init_db()
    orig_key = settings.OMNIDIM_API_KEY
    settings.OMNIDIM_API_KEY = ""
    db = SessionLocal()
    try:
        p = db.query(Patient).filter(Patient.id == 1).first()
        if not p:
            p = Patient(id=1, name="Padma")
            db.add(p)
            db.commit()

        # Ensure contact exists
        contact = db.query(Person).filter(Person.patient_id == 1, Person.is_emergency_contact == True).first()
        if not contact:
            contact = Person(
                patient_id=1,
                name="Shobamalika",
                relationship="granddaughter",
                phone="+919123507478",
                is_emergency_contact=True,
                priority=1,
            )
            db.add(contact)
            db.commit()
        yield
    finally:
        settings.OMNIDIM_API_KEY = orig_key
        db.close()


# -----------------------------------------------------------------------------
# Test 1: Call attempt is created correctly
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_1_call_attempt_created_correctly():
    db = SessionLocal()
    sess_id = f"test_sess_{uuid.uuid4().hex[:8]}"
    try:
        res = await call_orchestrator.initiate_call(
            patient_id=1,
            reason="Blood pressure check routine",
            source="routine",
            call_session_id=sess_id,
            db=db,
        )

        assert res.call_session_id == sess_id
        assert res.attempt_number == 1
        assert res.status == CallStatus.INITIATED
        assert res.is_escalated is False
        assert res.provider_call_id is not None
        assert res.recipient_phone is not None

        # Verify persisted in SQLite
        attempt = (
            db.query(CallAttempt)
            .filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 1)
            .first()
        )
        assert attempt is not None
        assert attempt.patient_id == 1
        assert attempt.provider == "omnidim"
        assert attempt.status == CallStatus.INITIATED.value
        assert attempt.is_technical_failure is False
    finally:
        db.close()


# -----------------------------------------------------------------------------
# Test 2: OmniDim provider response is mapped correctly
# -----------------------------------------------------------------------------
def test_2_omnidim_provider_response_mapped_correctly():
    # Answered / Completed mappings
    assert omnidim_service.normalize_status("completed") == CallStatus.ANSWERED
    assert omnidim_service.normalize_status("answered") == CallStatus.ANSWERED
    assert omnidim_service.normalize_status("human_answered") == CallStatus.ANSWERED
    assert omnidim_service.normalize_status("connected") == CallStatus.ANSWERED

    # Unanswered mappings
    assert omnidim_service.normalize_status("no-answer") == CallStatus.NO_ANSWER
    assert omnidim_service.normalize_status("no_answer") == CallStatus.NO_ANSWER
    assert omnidim_service.normalize_status("timeout") == CallStatus.NO_ANSWER
    assert omnidim_service.normalize_status("busy") == CallStatus.BUSY
    assert omnidim_service.normalize_status("voicemail_detected") == CallStatus.VOICEMAIL
    assert omnidim_service.normalize_status("machine_detected") == CallStatus.VOICEMAIL

    # Technical failure & Cancelled
    assert omnidim_service.normalize_status("failed") == CallStatus.FAILED
    assert omnidim_service.normalize_status("error") == CallStatus.FAILED
    assert omnidim_service.normalize_status("cancelled") == CallStatus.CANCELLED
    assert omnidim_service.normalize_status("dispatched") == CallStatus.INITIATED
    assert omnidim_service.normalize_status(None) == CallStatus.INITIATED


# -----------------------------------------------------------------------------
# Test 3: Answered call becomes 'answered' and does not trigger retry
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_3_answered_call_does_not_trigger_retry():
    db = SessionLocal()
    sess_id = f"test_sess_{uuid.uuid4().hex[:8]}"
    try:
        call_res = await call_orchestrator.initiate_call(
            patient_id=1,
            reason="Morning medication",
            source="routine",
            call_session_id=sess_id,
            db=db,
        )

        # Simulate provider webhook reporting that the call was answered
        outcome = await call_orchestrator.handle_call_result(
            provider_call_id=call_res.provider_call_id,
            provider_status="completed",
            duration_seconds=45,
            db=db,
        )

        assert outcome["status"] == "answered"
        assert outcome["action"] == "completed"

        # Verify DB status
        attempt = db.query(CallAttempt).filter(CallAttempt.provider_call_id == call_res.provider_call_id).first()
        assert attempt.status == CallStatus.ANSWERED.value

        # Verify no further attempt was generated
        attempts = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id).all()
        assert len(attempts) == 1
    finally:
        db.close()


# -----------------------------------------------------------------------------
# Test 4: First no_answer produces attempt 1 and triggers attempt 2
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_4_first_no_answer_produces_attempt_1_and_advances():
    db = SessionLocal()
    sess_id = f"test_sess_{uuid.uuid4().hex[:8]}"
    try:
        call_res = await call_orchestrator.initiate_call(
            patient_id=1,
            reason="Blood pressure check",
            source="routine",
            call_session_id=sess_id,
            db=db,
        )
        assert call_res.attempt_number == 1

        # Provider reports no_answer
        outcome = await call_orchestrator.handle_call_result(
            provider_call_id=call_res.provider_call_id,
            provider_status="no-answer",
            db=db,
        )

        assert outcome["status"] == "no_answer"
        assert outcome["action"] == "next_attempt_initiated"
        assert outcome["next_attempt_number"] == 2

        # Verify attempt 1 is no_answer and attempt 2 was created
        att1 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 1).first()
        att2 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 2).first()
        assert att1.status == CallStatus.NO_ANSWER.value
        assert att2 is not None
        assert att2.attempt_number == 2
    finally:
        db.close()


# -----------------------------------------------------------------------------
# Test 5: Second no_answer produces attempt 2 and triggers attempt 3
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_5_second_no_answer_triggers_attempt_3():
    db = SessionLocal()
    sess_id = f"test_sess_{uuid.uuid4().hex[:8]}"
    try:
        # 1st attempt
        c1 = await call_orchestrator.initiate_call(patient_id=1, reason="Test", call_session_id=sess_id, db=db)
        await call_orchestrator.handle_call_result(c1.provider_call_id, "no_answer", db=db)

        # 2nd attempt was auto-initiated
        att2 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 2).first()
        assert att2 is not None

        # 2nd attempt also reports busy / no_answer
        outcome2 = await call_orchestrator.handle_call_result(att2.provider_call_id, "busy", db=db)
        assert outcome2["status"] == "busy"
        assert outcome2["action"] == "next_attempt_initiated"
        assert outcome2["next_attempt_number"] == 3

        # 3rd attempt now exists
        att3 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 3).first()
        assert att3 is not None
        assert att3.attempt_number == 3
    finally:
        db.close()


# -----------------------------------------------------------------------------
# Test 6: Third no_answer produces attempt 3 and reaches escalation point
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_6_third_no_answer_reaches_escalation():
    db = SessionLocal()
    sess_id = f"test_sess_{uuid.uuid4().hex[:8]}"
    try:
        # Attempt 1 -> no answer
        c1 = await call_orchestrator.initiate_call(patient_id=1, reason="Emergency Routine", call_session_id=sess_id, db=db)
        await call_orchestrator.handle_call_result(c1.provider_call_id, "no_answer", db=db)

        # Attempt 2 -> no answer
        att2 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 2).first()
        await call_orchestrator.handle_call_result(att2.provider_call_id, "no_answer", db=db)

        # Attempt 3 -> no answer
        att3 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 3).first()
        outcome3 = await call_orchestrator.handle_call_result(att3.provider_call_id, "no_answer", db=db)

        # Must reach escalation point!
        assert outcome3["action"] == "escalated_to_caretaker"
        assert "alert_id" in outcome3

        # Verify Alert record was created
        alert = db.query(Alert).filter(Alert.id == outcome3["alert_id"]).first()
        assert alert is not None
        assert alert.alert_type == "calling_escalation"
        assert "3 consecutive calls" in alert.message

        # Verify no 4th attempt was created
        att4 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 4).first()
        assert att4 is None
    finally:
        db.close()


# -----------------------------------------------------------------------------
# Test 7: Successful/answered call resets the consecutive failure state
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_7_answered_call_resets_consecutive_failure_state():
    db = SessionLocal()
    sess_id = f"test_sess_{uuid.uuid4().hex[:8]}"
    try:
        # Attempt 1 -> no answer
        c1 = await call_orchestrator.initiate_call(patient_id=1, reason="Reset check", call_session_id=sess_id, db=db)
        await call_orchestrator.handle_call_result(c1.provider_call_id, "no_answer", db=db)

        # Attempt 2 is initiated
        att2 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 2).first()

        # Attempt 2 is ANSWERED!
        outcome = await call_orchestrator.handle_call_result(att2.provider_call_id, "completed", db=db)
        assert outcome["status"] == "answered"

        # Check consecutive failures: should be reset to 0!
        unanswered = call_orchestrator.get_consecutive_unanswered_attempts(sess_id, db)
        assert len(unanswered) == 0

        # Now if another call is placed in this session, it starts at attempt 1!
        c3 = await call_orchestrator.initiate_call(patient_id=1, reason="Follow-up after answer", call_session_id=sess_id, db=db)
        assert c3.attempt_number == 1
    finally:
        db.close()


# -----------------------------------------------------------------------------
# Test 8: Technical failure is not treated as a patient ignoring the call
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_8_technical_failure_does_not_advance_patient_unanswered_streak():
    db = SessionLocal()
    sess_id = f"test_sess_{uuid.uuid4().hex[:8]}"
    try:
        c1 = await call_orchestrator.initiate_call(patient_id=1, reason="Network test", call_session_id=sess_id, db=db)

        # Simulate technical provider outage / error
        outcome = await call_orchestrator.handle_call_result(
            provider_call_id=c1.provider_call_id,
            provider_status="failed",
            failure_reason="OmniDim API gateway 502 Bad Gateway",
            db=db,
        )

        assert outcome["status"] == "technical_failure"
        assert outcome["action"] == "logged_error"

        # Verify attempt has is_technical_failure = True
        att = db.query(CallAttempt).filter(CallAttempt.provider_call_id == c1.provider_call_id).first()
        assert att.is_technical_failure is True
        assert "502" in att.failure_reason

        # Crucially: Unanswered streak is NOT advanced by a technical error
        unanswered = call_orchestrator.get_consecutive_unanswered_attempts(sess_id, db)
        assert len(unanswered) == 0
    finally:
        db.close()


# -----------------------------------------------------------------------------
# Test 9: Webhook endpoint updates state from OmniDim payload
# -----------------------------------------------------------------------------
def test_9_omnidim_webhook_endpoint():
    db = SessionLocal()
    sess_id = f"test_sess_{uuid.uuid4().hex[:8]}"
    try:
        # Create an attempt directly in DB
        provider_id = f"omnidim_{uuid.uuid4().hex[:10]}"
        att = CallAttempt(
            call_session_id=sess_id,
            patient_id=1,
            attempt_number=1,
            provider="omnidim",
            provider_call_id=provider_id,
            recipient_phone="+919123507478",
            recipient_name="Shobamalika",
            status="initiated",
        )
        db.add(att)
        db.commit()

        # Send webhook from OmniDimension
        webhook_payload = {
            "call_id": provider_id,
            "status": "completed",
            "duration_seconds": 62,
            "metadata": {"session_id": sess_id, "attempt_number": 1},
        }

        resp = client.post("/v1/calls/webhook/omnidim", json=webhook_payload)
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "success"
        assert data["result"]["status"] == "answered"
    finally:
        db.close()


# -----------------------------------------------------------------------------
# Test 10: Orchestrated initiate API endpoint
# -----------------------------------------------------------------------------
def test_10_orchestrated_initiate_endpoint():
    sess_id = f"test_sess_{uuid.uuid4().hex[:8]}"
    resp = client.post(
        "/v1/calls/orchestrated/initiate",
        json={
            "patient_id": 1,
            "reason": "Afternoon vital check",
            "source": "routine",
            "call_session_id": sess_id,
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["call_session_id"] == sess_id
    assert data["attempt_number"] == 1
    assert data["status"] == "initiated"
    assert data["provider_call_id"] is not None

    # Fetch attempts via session endpoint
    get_resp = client.get(f"/v1/calls/attempts/{sess_id}")
    assert get_resp.status_code == 200
    attempts = get_resp.json()
    assert len(attempts) == 1
    assert attempts[0]["call_session_id"] == sess_id


# -----------------------------------------------------------------------------
# Test 11: Reminder Integration Point
# -----------------------------------------------------------------------------
def test_11_reminder_integration_point():
    db = SessionLocal()
    try:
        rem = Reminder(
            patient_id=1,
            title="Evening Metformin",
            scheduled_time="19:00",
            frequency="daily",
            is_critical=True,
            status="triggered",
        )
        db.add(rem)
        db.commit()

        session_id = trigger_reminder_call_orchestration(rem, db)
        assert session_id is not None
        assert str(rem.id) in session_id
    finally:
        db.close()


# =============================================================================
# 3-CONSECUTIVE-NO-ANSWER FLOW TESTS (END-TO-END VIA OMNIDIM INTEGRATION WEBHOOK)
# =============================================================================

# -----------------------------------------------------------------------------
# Test 12: Call 1 -> no-answer -> Call 2
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_12_call_1_no_answer_triggers_call_2():
    db = SessionLocal()
    sess_id = f"flow_sess_{uuid.uuid4().hex[:8]}"
    try:
        rem = Reminder(
            patient_id=1,
            title="Blood Pressure Check Flow 1",
            scheduled_time="10:00",
            status="triggered",
        )
        db.add(rem)
        db.commit()
        db.refresh(rem)

        # Call 1 is initiated
        c1 = await call_orchestrator.initiate_call(
            patient_id=1,
            reason="Blood pressure check",
            source="reminder_routine",
            call_session_id=sess_id,
            reminder_id=rem.id,
            db=db,
        )
        assert c1.attempt_number == 1
        assert c1.status == CallStatus.INITIATED

        # OmniDim post-call webhook reports no-answer
        payload = {
            "call_id": c1.provider_call_id,
            "call_status": "no-answer",
            "metadata": {
                "session_id": sess_id,
                "attempt_number": 1,
                "reminder_id": rem.id,
            },
        }
        res = client.post("/v1/integrations/omnidim/post-call", json=payload)
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["action"] == "next_attempt_initiated"

        # Verify DB state: Call 1 is no_answer, Call 2 exists and is initiated
        db.expire_all()
        att1 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 1).first()
        att2 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 2).first()
        assert att1.status == CallStatus.NO_ANSWER.value
        assert att2 is not None
        assert att2.attempt_number == 2
        assert att2.status == CallStatus.INITIATED.value

        # Verify reminder retry_count is 1
        rem_db = db.query(Reminder).filter(Reminder.id == rem.id).first()
        assert rem_db.retry_count == 1
    finally:
        db.close()


# -----------------------------------------------------------------------------
# Test 13: Call 2 -> no-answer -> Call 3
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_13_call_2_no_answer_triggers_call_3():
    db = SessionLocal()
    sess_id = f"flow_sess_{uuid.uuid4().hex[:8]}"
    try:
        rem = Reminder(
            patient_id=1,
            title="Blood Pressure Check Flow 2",
            scheduled_time="10:00",
            status="triggered",
        )
        db.add(rem)
        db.commit()
        db.refresh(rem)

        # Call 1 -> no-answer
        c1 = await call_orchestrator.initiate_call(
            patient_id=1,
            reason="Blood pressure check",
            source="reminder_routine",
            call_session_id=sess_id,
            reminder_id=rem.id,
            db=db,
        )
        client.post(
            "/v1/integrations/omnidim/post-call",
            json={"call_id": c1.provider_call_id, "call_status": "no-answer", "metadata": {"session_id": sess_id, "attempt_number": 1, "reminder_id": rem.id}},
        )

        db.expire_all()
        att2 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 2).first()
        assert att2 is not None

        # Call 2 -> no-answer
        res2 = client.post(
            "/v1/integrations/omnidim/post-call",
            json={"call_id": att2.provider_call_id, "call_status": "no-answer", "metadata": {"session_id": sess_id, "attempt_number": 2, "reminder_id": rem.id}},
        )
        assert res2.status_code == 200
        data2 = res2.json()
        assert data2["action"] == "next_attempt_initiated"

        # Verify Call 3 exists and is initiated
        db.expire_all()
        att2_updated = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 2).first()
        att3 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 3).first()
        assert att2_updated.status == CallStatus.NO_ANSWER.value
        assert att3 is not None
        assert att3.attempt_number == 3
        assert att3.status == CallStatus.INITIATED.value

        # Reminder retry_count is now 2
        rem_db = db.query(Reminder).filter(Reminder.id == rem.id).first()
        assert rem_db.retry_count == 2
    finally:
        db.close()


# -----------------------------------------------------------------------------
# Test 14: Call 3 -> no-answer -> caretaker alert
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_14_call_3_no_answer_triggers_caretaker_alert():
    db = SessionLocal()
    sess_id = f"flow_sess_{uuid.uuid4().hex[:8]}"
    try:
        rem = Reminder(
            patient_id=1,
            title="Urgent Morning Heart Medication",
            scheduled_time="08:00",
            status="triggered",
        )
        db.add(rem)
        db.commit()
        db.refresh(rem)

        # Call 1 -> no-answer
        c1 = await call_orchestrator.initiate_call(patient_id=1, reason="Heart Medication", call_session_id=sess_id, reminder_id=rem.id, db=db)
        client.post("/v1/integrations/omnidim/post-call", json={"call_id": c1.provider_call_id, "call_status": "no-answer", "metadata": {"session_id": sess_id, "attempt_number": 1, "reminder_id": rem.id}})

        # Call 2 -> no-answer
        db.expire_all()
        att2 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 2).first()
        client.post("/v1/integrations/omnidim/post-call", json={"call_id": att2.provider_call_id, "call_status": "no-answer", "metadata": {"session_id": sess_id, "attempt_number": 2, "reminder_id": rem.id}})

        # Call 3 -> no-answer
        db.expire_all()
        att3 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 3).first()
        res3 = client.post("/v1/integrations/omnidim/post-call", json={"call_id": att3.provider_call_id, "call_status": "no-answer", "metadata": {"session_id": sess_id, "attempt_number": 3, "reminder_id": rem.id}})

        assert res3.status_code == 200
        data3 = res3.json()
        assert data3["action"] == "escalated_to_caretaker"

        db.expire_all()
        # Verify Call 3 marked as no_answer
        att3_updated = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 3).first()
        assert att3_updated.status == CallStatus.NO_ANSWER.value

        # Verify NO Call 4 created
        att4 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 4).first()
        assert att4 is None

        # Verify Caretaker Alert was triggered
        alert = (
            db.query(Alert)
            .filter(Alert.reminder_id == rem.id, Alert.alert_type == "calling_escalation")
            .order_by(Alert.id.desc())
            .first()
        )
        assert alert is not None
        assert "3 consecutive calls" in alert.message
        assert alert.status == "sent"

        # Verify reminder status is escalated
        rem_db = db.query(Reminder).filter(Reminder.id == rem.id).first()
        assert rem_db.status == "escalated"
        assert rem_db.retry_count == 3
    finally:
        db.close()


# -----------------------------------------------------------------------------
# Test 15: Call 1 -> completed -> no retry
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_15_call_1_completed_no_retry():
    db = SessionLocal()
    sess_id = f"flow_sess_{uuid.uuid4().hex[:8]}"
    try:
        rem = Reminder(
            patient_id=1,
            title="Water Intake Reminder",
            scheduled_time="11:00",
            status="triggered",
        )
        db.add(rem)
        db.commit()
        db.refresh(rem)

        c1 = await call_orchestrator.initiate_call(patient_id=1, reason="Water intake", call_session_id=sess_id, reminder_id=rem.id, db=db)

        # Call 1 completed
        res = client.post(
            "/v1/integrations/omnidim/post-call",
            json={"call_id": c1.provider_call_id, "call_status": "completed", "call_duration": 40, "metadata": {"session_id": sess_id, "attempt_number": 1, "reminder_id": rem.id}},
        )
        assert res.status_code == 200
        assert res.json()["action"] == "completed"

        db.expire_all()
        # Verify Call 1 status answered
        att1 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 1).first()
        assert att1.status == CallStatus.ANSWERED.value

        # Verify no Call 2
        att2 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 2).first()
        assert att2 is None

        # Verify reminder acknowledged & retry count 0
        rem_db = db.query(Reminder).filter(Reminder.id == rem.id).first()
        assert rem_db.status == "acknowledged"
        assert rem_db.retry_count == 0

        # Verify no caretaker alert
        alert = db.query(Alert).filter(Alert.reminder_id == rem.id, Alert.alert_type == "calling_escalation").first()
        assert alert is None
    finally:
        db.close()


# -----------------------------------------------------------------------------
# Test 16: Call 2 -> completed -> no third call
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_16_call_2_completed_no_third_call():
    db = SessionLocal()
    sess_id = f"flow_sess_{uuid.uuid4().hex[:8]}"
    try:
        rem = Reminder(
            patient_id=1,
            title="Lunch Check",
            scheduled_time="13:00",
            status="triggered",
        )
        db.add(rem)
        db.commit()
        db.refresh(rem)

        c1 = await call_orchestrator.initiate_call(patient_id=1, reason="Lunch", call_session_id=sess_id, reminder_id=rem.id, db=db)
        client.post("/v1/integrations/omnidim/post-call", json={"call_id": c1.provider_call_id, "call_status": "no-answer", "metadata": {"session_id": sess_id, "attempt_number": 1, "reminder_id": rem.id}})

        db.expire_all()
        att2 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 2).first()
        assert att2 is not None

        # Call 2 is answered/completed!
        res2 = client.post(
            "/v1/integrations/omnidim/post-call",
            json={"call_id": att2.provider_call_id, "call_status": "completed", "call_duration": 55, "metadata": {"session_id": sess_id, "attempt_number": 2, "reminder_id": rem.id}},
        )
        assert res2.status_code == 200
        assert res2.json()["action"] == "completed"

        db.expire_all()
        att2_updated = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 2).first()
        assert att2_updated.status == CallStatus.ANSWERED.value

        # Verify NO Call 3 was created
        att3 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 3).first()
        assert att3 is None

        # Verify reminder acknowledged & retry count reset to 0
        rem_db = db.query(Reminder).filter(Reminder.id == rem.id).first()
        assert rem_db.status == "acknowledged"
        assert rem_db.retry_count == 0

        # No caretaker alert
        alert = db.query(Alert).filter(Alert.reminder_id == rem.id, Alert.alert_type == "calling_escalation").first()
        assert alert is None
    finally:
        db.close()


# -----------------------------------------------------------------------------
# Test 17: Call 3 -> completed -> no caretaker missed-call alert
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_17_call_3_completed_no_caretaker_missed_call_alert():
    db = SessionLocal()
    sess_id = f"flow_sess_{uuid.uuid4().hex[:8]}"
    try:
        rem = Reminder(
            patient_id=1,
            title="Evening Walk",
            scheduled_time="17:00",
            status="triggered",
        )
        db.add(rem)
        db.commit()
        db.refresh(rem)

        # Call 1 -> no-answer
        c1 = await call_orchestrator.initiate_call(patient_id=1, reason="Evening Walk", call_session_id=sess_id, reminder_id=rem.id, db=db)
        client.post("/v1/integrations/omnidim/post-call", json={"call_id": c1.provider_call_id, "call_status": "no-answer", "metadata": {"session_id": sess_id, "attempt_number": 1, "reminder_id": rem.id}})

        # Call 2 -> no-answer
        db.expire_all()
        att2 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 2).first()
        client.post("/v1/integrations/omnidim/post-call", json={"call_id": att2.provider_call_id, "call_status": "no-answer", "metadata": {"session_id": sess_id, "attempt_number": 2, "reminder_id": rem.id}})

        # Call 3 is answered/completed!
        db.expire_all()
        att3 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 3).first()
        res3 = client.post(
            "/v1/integrations/omnidim/post-call",
            json={"call_id": att3.provider_call_id, "call_status": "completed", "call_duration": 60, "metadata": {"session_id": sess_id, "attempt_number": 3, "reminder_id": rem.id}},
        )
        assert res3.status_code == 200
        assert res3.json()["action"] == "completed"

        db.expire_all()
        att3_updated = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 3).first()
        assert att3_updated.status == CallStatus.ANSWERED.value

        # Crucially: No caretaker missed-call alert generated
        alert = db.query(Alert).filter(Alert.reminder_id == rem.id, Alert.alert_type == "calling_escalation").first()
        assert alert is None

        # Reminder acknowledged & retry count reset to 0
        rem_db = db.query(Reminder).filter(Reminder.id == rem.id).first()
        assert rem_db.status == "acknowledged"
        assert rem_db.retry_count == 0
    finally:
        db.close()


# -----------------------------------------------------------------------------
# Test 18: No fourth call after 3 consecutive no-answers
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_18_no_fourth_call_after_3_consecutive_no_answers():
    db = SessionLocal()
    sess_id = f"flow_sess_{uuid.uuid4().hex[:8]}"
    try:
        rem = Reminder(patient_id=1, title="Max Retries Test", scheduled_time="12:00", status="triggered")
        db.add(rem)
        db.commit()
        db.refresh(rem)

        # 3 no-answers
        c1 = await call_orchestrator.initiate_call(patient_id=1, reason="Test", call_session_id=sess_id, reminder_id=rem.id, db=db)
        client.post("/v1/integrations/omnidim/post-call", json={"call_id": c1.provider_call_id, "call_status": "no-answer", "metadata": {"session_id": sess_id, "attempt_number": 1, "reminder_id": rem.id}})

        db.expire_all()
        att2 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 2).first()
        client.post("/v1/integrations/omnidim/post-call", json={"call_id": att2.provider_call_id, "call_status": "no-answer", "metadata": {"session_id": sess_id, "attempt_number": 2, "reminder_id": rem.id}})

        db.expire_all()
        att3 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 3).first()
        client.post("/v1/integrations/omnidim/post-call", json={"call_id": att3.provider_call_id, "call_status": "no-answer", "metadata": {"session_id": sess_id, "attempt_number": 3, "reminder_id": rem.id}})

        db.expire_all()
        attempts = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id).all()
        assert len(attempts) == 3

        # Explicitly attempt to initiate a fourth call
        c4 = await call_orchestrator.initiate_call(
            patient_id=1,
            reason="Illegal 4th call attempt",
            call_session_id=sess_id,
            reminder_id=rem.id,
            db=db,
        )
        assert c4.is_escalated is True
        assert c4.attempt_number == 3

        # Verify database still has exactly 3 attempts
        db.expire_all()
        attempts_after = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id).all()
        assert len(attempts_after) == 3
        att4 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 4).first()
        assert att4 is None
    finally:
        db.close()


# -----------------------------------------------------------------------------
# Test 19: Duplicate webhook does not create an extra retry
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_19_duplicate_webhook_does_not_create_extra_retry():
    db = SessionLocal()
    sess_id = f"flow_sess_{uuid.uuid4().hex[:8]}"
    try:
        rem = Reminder(patient_id=1, title="Idempotency Test", scheduled_time="15:00", status="triggered")
        db.add(rem)
        db.commit()
        db.refresh(rem)

        # Call 1 is initiated
        c1 = await call_orchestrator.initiate_call(patient_id=1, reason="Test", call_session_id=sess_id, reminder_id=rem.id, db=db)

        # First webhook delivery for Call 1: no-answer -> triggers Call 2
        webhook_data = {
            "call_id": c1.provider_call_id,
            "call_status": "no-answer",
            "metadata": {"session_id": sess_id, "attempt_number": 1, "reminder_id": rem.id},
        }
        res1 = client.post("/v1/integrations/omnidim/post-call", json=webhook_data)
        assert res1.status_code == 200
        assert res1.json()["action"] == "next_attempt_initiated"

        db.expire_all()
        attempts_after_first = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id).all()
        assert len(attempts_after_first) == 2

        # DUPLICATE webhook delivery for Call 1
        res2 = client.post("/v1/integrations/omnidim/post-call", json=webhook_data)
        assert res2.status_code == 200
        assert res2.json()["action"] == "already_processed"

        # Verify NO duplicate attempt was created (still exactly 2 attempts)
        db.expire_all()
        attempts_after_duplicate = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id).all()
        assert len(attempts_after_duplicate) == 2
    finally:
        db.close()


# -----------------------------------------------------------------------------
# Test 20: Phone number normalization for Indian 10-digit numbers
# -----------------------------------------------------------------------------
def test_20_phone_number_normalization():
    # 10-digit Indian number becomes +91-prefixed
    assert omnidim_service.normalize_phone_number("9123507478") == "+919123507478"
    assert omnidim_service.normalize_phone_number("  9123507478  ") == "+919123507478"
    assert omnidim_service.normalize_phone_number("9876543210") == "+919876543210"

    # Already formatted E.164 number remains unchanged
    assert omnidim_service.normalize_phone_number("+919123507478") == "+919123507478"
    assert omnidim_service.normalize_phone_number("+919876543210") == "+919876543210"
    assert omnidim_service.normalize_phone_number("+14155552671") == "+14155552671"

    # Empty / None
    assert omnidim_service.normalize_phone_number("") == ""
    assert omnidim_service.normalize_phone_number(None) == ""


# -----------------------------------------------------------------------------
# Test 21: Outbound OmniDim request payload normalizes 10-digit to_number
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_21_dispatch_call_normalizes_to_number_in_payload():
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {"call_id": "call_norm_123", "status": "dispatched"}

    with patch.object(settings, "OMNIDIM_API_KEY", "test_key_norm"):
        with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
            mock_post.return_value = mock_resp

            # 1. Dispatch with 10-digit raw number -> becomes +919123507478
            res1 = await omnidim_service.dispatch_call(to_number="9123507478")
            assert res1.success is True
            assert mock_post.call_args[1]["json"]["to_number"] == "+919123507478"

            # 2. Dispatch with already formatted +91 number -> remains +919123507478
            res2 = await omnidim_service.dispatch_call(to_number="+919123507478")
            assert res2.success is True
            assert mock_post.call_args[1]["json"]["to_number"] == "+919123507478"


# -----------------------------------------------------------------------------
# Test 22: Duplicate webhook on attempt 3 does not trigger duplicate caretaker alert
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_22_duplicate_webhook_on_attempt_3_does_not_duplicate_caretaker_alert():
    db = SessionLocal()
    sess_id = f"flow_sess_{uuid.uuid4().hex[:8]}"
    try:
        rem = Reminder(patient_id=1, title="Idempotent Escalation", scheduled_time="16:00", status="triggered")
        db.add(rem)
        db.commit()
        db.refresh(rem)

        # Attempt 1 -> no-answer
        c1 = await call_orchestrator.initiate_call(patient_id=1, reason="Test", call_session_id=sess_id, reminder_id=rem.id, db=db)
        client.post("/v1/integrations/omnidim/post-call", json={"call_id": c1.provider_call_id, "call_status": "no-answer", "metadata": {"session_id": sess_id, "attempt_number": 1, "reminder_id": rem.id}})

        # Attempt 2 -> no-answer
        db.expire_all()
        att2 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 2).first()
        client.post("/v1/integrations/omnidim/post-call", json={"call_id": att2.provider_call_id, "call_status": "no-answer", "metadata": {"session_id": sess_id, "attempt_number": 2, "reminder_id": rem.id}})

        # Attempt 3 -> no-answer (first delivery)
        db.expire_all()
        att3 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 3).first()
        webhook_data_3 = {
            "call_id": att3.provider_call_id,
            "call_status": "no-answer",
            "metadata": {"session_id": sess_id, "attempt_number": 3, "reminder_id": rem.id},
        }
        res3_first = client.post("/v1/integrations/omnidim/post-call", json=webhook_data_3)
        assert res3_first.status_code == 200
        assert res3_first.json()["action"] == "escalated_to_caretaker"

        db.expire_all()
        alerts_first = db.query(Alert).filter(Alert.reminder_id == rem.id, Alert.alert_type == "calling_escalation").all()
        assert len(alerts_first) == 1

        # Duplicate webhook delivery for Attempt 3
        res3_dup = client.post("/v1/integrations/omnidim/post-call", json=webhook_data_3)
        assert res3_dup.status_code == 200
        assert res3_dup.json()["action"] == "already_processed"

        # Verify caretaker alert was NOT duplicated (still exactly 1 alert)
        db.expire_all()
        alerts_dup = db.query(Alert).filter(Alert.reminder_id == rem.id, Alert.alert_type == "calling_escalation").all()
        assert len(alerts_dup) == 1

        # Still exactly 3 attempts
        attempts = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id).all()
        assert len(attempts) == 3
    finally:
        db.close()


# -----------------------------------------------------------------------------
# Test 23: Technical failure via webhook does not trigger retry or count as no-answer
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_23_technical_failure_via_webhook_does_not_trigger_retry_or_count_as_no_answer():
    db = SessionLocal()
    sess_id = f"flow_sess_{uuid.uuid4().hex[:8]}"
    try:
        rem = Reminder(patient_id=1, title="Technical Fail Test", scheduled_time="17:00", status="triggered")
        db.add(rem)
        db.commit()
        db.refresh(rem)

        # Initiate Attempt 1
        c1 = await call_orchestrator.initiate_call(patient_id=1, reason="Test", call_session_id=sess_id, reminder_id=rem.id, db=db)

        # Webhook reports technical failure from carrier/provider
        res = client.post(
            "/v1/integrations/omnidim/post-call",
            json={
                "call_id": c1.provider_call_id,
                "call_status": "failed",
                "error": "Upstream SIP Trunk 503 Service Unavailable",
                "metadata": {"session_id": sess_id, "attempt_number": 1, "reminder_id": rem.id},
            },
        )
        assert res.status_code == 200
        assert res.json()["action"] == "logged_error"

        db.expire_all()
        att1 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 1).first()
        assert att1.status == CallStatus.FAILED.value
        assert att1.is_technical_failure is True

        # Crucially: NO attempt 2 was scheduled (we don't retry technical provider crashes as patient no-answers)
        att2 = db.query(CallAttempt).filter(CallAttempt.call_session_id == sess_id, CallAttempt.attempt_number == 2).first()
        assert att2 is None

        # Unanswered count is 0
        unanswered = call_orchestrator.get_consecutive_unanswered_attempts(sess_id, db)
        assert len(unanswered) == 0

        # No caretaker alert
        alert = db.query(Alert).filter(Alert.reminder_id == rem.id, Alert.alert_type == "calling_escalation").first()
        assert alert is None
    finally:
        db.close()



