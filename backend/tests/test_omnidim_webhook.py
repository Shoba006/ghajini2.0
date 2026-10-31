from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_omnidim_post_call_completed():
    sample_payload = {
        "call_id": 24877,
        "bot_id": 551,
        "bot_name": "Ghajini Care Assistant",
        "phone_number": "+1234567890",
        "to_number": "+919123507478",
        "call_date": "2026-10-30 23:50:00",
        "call_status": "completed",
        "call_duration": "01:15",
        "metadata": {
            "session_id": "sess_test_123",
            "patient_id": 1,
            "attempt_number": 1,
        },
        "call_report": {
            "summary": "Patient acknowledged reminder",
            "sentiment": "Positive",
        },
    }

    response = client.post("/v1/integrations/omnidim/post-call", json=sample_payload)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["received"] is True
    assert data["call_id"] == 24877
    assert data["call_status"] == "completed"


def test_omnidim_post_call_no_answer():
    payload = {
        "call_id": 24878,
        "bot_id": 551,
        "to_number": "+919123507478",
        "call_status": "no-answer",
        "metadata": {
            "session_id": "sess_test_124",
            "patient_id": 1,
            "attempt_number": 1,
        },
    }
    response = client.post("/v1/integrations/omnidim/post-call", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["received"] is True
    assert data["call_id"] == 24878
    assert data["call_status"] == "no-answer"
