# Ghajini 2.0 - AI Memory Companion for Alzheimer's Patients.

A full-stack, local-first AI memory companion designed specifically for Alzheimer's patients and their caregivers. It features high-accuracy face recognition, grounded semantic memory retrieval, Ollama LLM integration, offline voice transcription with faster-whisper, automated medication reminders with iCal RRULE escalation, emergency phrase interception, caregiver alerts, Caregiver Analytics Dashboard, and a high-contrast elderly-friendly UI.

---

## Architecture Overview

- **Backend**: FastAPI (Python 3.11), SQLAlchemy 2.x, SQLite, Pydantic v2
- **Voice Transcription**: `faster-whisper` (model `small`, int8, CPU) with VAD filtering and language detection (`en`, `hi`, `pa`)
- **Face Engine**: InsightFace (`buffalo_l`) + FAISS (`IndexFlatIP` on 512-d L2 normalized embeddings)
- **Memory Retrieval**: SentenceTransformers (`paraphrase-multilingual-MiniLM-L12-v2`) + FAISS (`IndexFlatIP` on 384-d L2 normalized vectors)
- **Chat / LLM**: Local Ollama (`llama3.2:3b`) with strict grounding prompts, multilingual fallback ("I am not sure" in English, Hindi, Punjabi), and emergency phrase interception
- **Caregiver Dashboard**: 7-day adherence metrics, weekly dose bar chart, top repeated questions tracking, and template-based daily activity summary smoothed by Ollama
- **Reminders & Escalation**: APScheduler + `python-dateutil` RRULE recurrence. 15-second frontend polling, 5-minute unacknowledged repeat, quiet hours suppression (22:00-06:00), and caregiver alert escalation via Twilio SMS stub
- **Demo Mode**: Instant reset (`POST /v1/demo/reset`), live 1-minute reminder trigger, and hidden Demo Tools screen
- **Privacy & Audit**: Strict face consent validation, complete data wipe, audit log (`audit_logs`), and GDPR/HIPAA compliant JSON export archive (ZIP)
- **Frontend**: Flutter (Android + Web), Riverpod, GoRouter, Push-to-Talk audio recording (`record`), TTS (`flutter_tts` at rate 0.8), local notifications (`flutter_local_notifications`), emergency phone dialer (`url_launcher`), and high-contrast elderly-friendly UI (20sp+ typography, 64dp+ touch targets)

---

## Repo Structure

```
ghajini_2.0/
  backend/
    app/
      main.py                   (Preloads models, warm-up timer, /health)
      core/config.py            (Settings from .env using pydantic-settings)
      db/session.py, models.py  (SQLAlchemy 2.x, SQLite auto-migration, Place model)
      modules/
        people/router.py        (Registration, consent, face vectors, recognition)
        faces/engine.py         (InsightFace buffalo_l + FAISS IndexFlatIP)
        memory/router.py, retrieval.py (SentenceTransformers + FAISS)
        chat/router.py, prompts.py, llm_client.py (Emergency interception, Ollama)
        voice/router.py, transcriber.py (faster-whisper small int8 CPU + VAD)
        alerts/router.py, service.py    (Caregiver alert dispatcher + Twilio SMS)
        dashboard/router.py     (Adherence %, daily summary, top questions)
        demo/router.py          (Demo reset, live reminder trigger)
        reminders/router.py, scheduler.py (APScheduler + RRULE + escalation)
        privacy/router.py       (ZIP export, complete data wipe, audit log)
    scripts/
      seed_demo_data.py
      eval_faces.py             (TAR, FAR, FACE_T_HIGH/LOW threshold sweep)
      eval_qa.py                (20 questions, accuracy, hallucination count)
    tests/test_api.py           (14 pytest tests covering all critical paths)
    eval_data/                  (Evaluation dataset for faces and Q&A)
    eval_results/               (Output JSON reports for evaluations)
    demo_assets/                (Sample photos for Priya, Dr. Sharma, Arun)
    requirements.txt, .env.example, Dockerfile
  frontend/
    lib/
      main.dart
      core/constants.dart, theme.dart, api_client.dart
      models/person.dart, recognition_result.dart, memory.dart, reminder.dart, alert_model.dart, dashboard_summary.dart
      services/api_service.dart, tts_service.dart
      providers/app_providers.dart
      router/app_router.dart
      screens/
        home_screen.dart        (Greeting, due reminder card, SOS, Call Family, Demo Tools)
        recognize_screen.dart   (Camera capture / photo pick, voice output, confirm card)
        ask_screen.dart         (Push-to-talk mic, 15s timeout, calm loading, lang switch)
        caregiver_screen.dart   (Reminders manager, recent alerts feed)
        dashboard_screen.dart   (Adherence gauge, custom weekly bar chart, top questions)
        privacy_screen.dart     (GDPR export, person delete, wipe everything)
        add_person_screen.dart  (Caregiver: name, relationship, notes, consent, photos)
    pubspec.yaml
  scripts/
    start_tunnel.py             (Public Cloudflare Tunnel / ngrok launcher)
  DEMO_CHECKLIST.md             (1-page demo script, steps & fallback plan)
  docker-compose.yml            (FastAPI + Ollama + MongoDB)
  README.md
```

---

## Run the Demo (Exact Commands)

### 1. Start Services via Docker Compose
Starts MongoDB, Ollama, and the FastAPI backend in containers:
```bash
docker-compose up -d
docker exec -it ghajini_ollama ollama pull llama3.2:3b
docker exec -it ghajini_api python scripts/seed_demo_data.py
```

### 2. Or Start Locally (Native)
**Terminal 1 — MongoDB & Ollama**:
```bash
# Start MongoDB (if installed locally or via docker)
docker run -d -p 27017:27017 --name ghajini_mongo mongo:latest

# Start Ollama & pull model
ollama serve
ollama pull llama3.2:3b
```

**Terminal 2 — FastAPI Backend**:
```bash
cd backend
.\.venv\Scripts\activate      # On Windows
# source .venv/bin/activate   # On Linux/macOS

# Seed pristine demo data
python scripts/seed_demo_data.py

# Start backend server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

**Terminal 3 — Flutter Mobile or Web**:
```bash
cd frontend

# Mobile (Android Emulator / Device)
flutter run -d android --dart-define=API_URL=http://10.0.2.2:8000/v1

# Web (Chrome)
flutter run -d chrome --dart-define=API_URL=http://localhost:8000/v1
```

**Terminal 4 (Optional) — Public Web Build & Tunnel**:
To expose the backend publicly for a Vercel/Netlify web deployment:
```bash
python scripts/start_tunnel.py
# Use the printed URL in your build:
flutter build web --dart-define=API_URL=https://<your-tunnel-url>/v1
```

---

## Evaluation Scripts

### 1. Face Threshold Tuning (`eval_faces.py`)
Reads `backend/eval_data/`, enrolls the first 3 photos of each person, tests positive photos and `_unknown/` strangers, sweeps thresholds, and writes `eval_results/faces.json`:
```bash
python backend/scripts/eval_faces.py
```

### 2. Grounding & Q&A Accuracy Check (`eval_qa.py`)
Tests 20 questions in English, Hindi (Hinglish), and Punjabi. Verifies that hallucinations are 0, out-of-domain queries return fallback, and logs latency:
```bash
python backend/scripts/eval_qa.py
```

---

## Running the Automated Test Suite

Runs all 14 end-to-end integration tests:
```bash
python -m pytest backend/tests -v
```

All 14 tests verify:
1. `test_1_health`: Health check status
2. `test_2_create_person`: Person creation with consent validation
3. `test_3_ask_known_fact`: Grounded retrieval of stored memory
4. `test_4_ask_unknown_fact`: Fallback message on unknown questions
5. `test_5_delete_person`: Person deletion
6. `test_6_transcribe_wav`: Faster-whisper WAV transcription
7. `test_7_emergency_phrase_creates_alert_and_skips_llm`: Emergency keyword interception
8. `test_8_reminder_fires_and_escalates`: Scheduling, polling, 5m repetition, and escalation
9. `test_9_delete_person_removes_vectors_and_fails_recognition`: Vector purge & recognition failure
10. `test_10_privacy_export_returns_zip`: GDPR/HIPAA ZIP archive export
11. `test_11_dashboard_summary_numbers_match_seeded_logs`: 7-day adherence & daily report
12. `test_12_demo_reset_restores_seed_state`: Demo reset endpoint (`/v1/demo/reset`)
13. `test_13_health_endpoint_component_statuses`: Component checks (`mongo`, `ollama`, `face_model`, `whisper_model`)
14. `test_14_timeout_and_fallback_prompt`: Timeout & ungrounded hallucination prevention

---

## API Endpoints Reference

All endpoints are prefixed with `/v1` and return JSON:

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` | Health check reporting status of Mongo, Ollama, Face, Whisper |
| `GET` | `/dashboard/summary` | 7-day adherence %, weekly history, top questions, alert count |
| `GET` | `/dashboard/daily-summary`| Factual daily activity summary for family caregivers |
| `POST` | `/demo/reset` | Resets demo data (3 people, 10 memories, 2 reminders, 1 place) |
| `POST` | `/demo/trigger-reminder`| Forces nearest reminder to trigger immediately for live demo |
| `POST` | `/people` | Register person (`consent=true` required) |
| `GET` | `/people` | List registered people & face count |
| `POST` | `/people/{id}/faces` | Upload multipart face photo (rejects without consent) |
| `DELETE` | `/people/{id}` | Delete person, files, and FAISS vectors |
| `POST` | `/recognize` | Multipart image -> status (`match`, `uncertain`, `unknown`, `no_face`) |
| `POST` | `/memories` | Create memory note (auto-embedded into FAISS) |
| `GET` | `/memories` | List patient memories |
| `POST` | `/ask` | Semantic retrieval + LLM answer / Emergency interception |
| `POST` | `/voice/transcribe` | Multipart audio transcription (faster-whisper small int8) |
| `POST` | `/alerts/help` | SOS emergency trigger |
| `GET` | `/alerts` | Caregiver alerts history feed |
| `POST` | `/reminders` | Create reminder with optional iCal RRULE |
| `GET` | `/reminders/upcoming` | List upcoming reminders |
| `GET` | `/reminders/due` | Poll currently due reminders (polled every 15s) |
| `PUT` | `/reminders/{id}` | Edit a reminder |
| `DELETE` | `/reminders/{id}` | Delete a reminder |
| `POST` | `/reminders/{id}/respond` | Respond (`acknowledged`, `snoozed`, `distressed`) |
| `GET` | `/privacy/export` | Download full personal data as a ZIP archive (`export.json`) |
| `DELETE` | `/privacy/all` | Wipe all patient records, faces, vectors, and audit logs |
| `POST` | `/companion/message` | Companion AI brain: intent router, fact retrieval, mood reassurance |
| `GET` | `/companion/proactive` | Proactive morning greeting, gentle check-ins, evening wind-down (poll 30s) |
| `POST` | `/companion/check-in/respond` | Patient check-in response (`ok`, `need_help` -> alerts caregiver) |
| `POST` | `/companion/teach` | Caregiver form: add plain-text fact, sanitizes injections, auto-embeds |
| `GET` | `/companion/settings` | Caregiver companion configuration (wake time, language, tone, quiet hours) |
| `POST` | `/companion/settings` | Update caregiver companion settings |
| `GET` | `/companion/conversations` | Conversation history with intent, mood, and grounded flag |
| `POST` | `/companion/conversations/{id}/feedback` | Caregiver feedback: mark reply as wrong to exclude from retrieval |

---

## Patient AI Companion Walkthrough & How to Try Each Intent

The Patient AI Companion is an elderly-friendly, empathetic conversational assistant designed specifically for individuals with memory loss. It uses a rule-first intent router with strict anti-hallucination guardrails and multilingual support (English, Hindi, Punjabi).

### Trying Each Intent via `/v1/companion/message`

1. **Emergency (`emergency`)**:
   - **Sample inputs**: `"Help, I fell"`, `"Madad karo main gir gayi"`, `"Ghabrahat ho rahi hai"`, `"Bachao"`
   - **Behavior**: Skips the LLM completely, immediately dispatches a caregiver alert to the database/SMS, and replies with calm reassurance: *"Help is coming. I am telling your family."* (`action: ["show_sos", "call_family"]`).

2. **Who is This? (`who_is`)**:
   - **Sample inputs**: `"Who is Priya?"`, `"प्रिया कौन है?"`, `"Who is Dr. Sharma?"`
   - **Behavior**: Queries the consented People table and semantic memories. Returns the relationship, notes, and a person photo card.

3. **Where / When (`where_when`)**:
   - **Sample inputs**: `"Where am I?"`, `"What day is it today?"`, `"What time is it?"`, `"Aaj kaun sa din hai?"`
   - **Behavior**: Combines the real-time system clock, date, and registered Home address from the `Place` table to give exact orientation.

4. **Medication & Routine (`medicine`)**:
   - **Sample inputs**: `"Did I take my medicine today?"`, `"Dawai li thi maine?"`
   - **Behavior**: Queries `reminder_logs` for today's doses only.
   - **Medical Advice Guardrail**: If asked for dosage advice (*"How many tablets should I take?"*), refuses medical consultation and replies: *"Please ask your doctor."*

5. **Routine & Schedule (`routine`)**:
   - **Sample inputs**: `"What do I do today?"`, `"What is next today?"`, `"Aaj kya karna hai?"`
   - **Behavior**: Lists today's upcoming scheduled tasks and reminders in chronological order.

6. **Call Family (`call_family`)**:
   - **Sample inputs**: `"Call my daughter"`, `"Call Priya"`, `"Phone milao"`, `"Call family"`
   - **Behavior**: Returns `action: ["call_family"]` which prompts the app to trigger the emergency phone dialer.

7. **Smalltalk & Warmth (`smalltalk`)**:
   - **Sample inputs**: `"Hello"`, `"Good morning"`, `"Namaste"`, `"Sat sri akal"`, `"Kaise ho?"`
   - **Behavior**: Replies with a friendly greeting in the patient's language.

8. **Unknown / Unanswerable Query (`unknown`)**:
   - **Sample inputs**: `"What is the secret code to the safe in Antarctica?"`
   - **Behavior**: Anti-hallucination guardrail catches zero grounding and replies safely: *"I am not sure. Shall I call your family?"*

---

## Status of Features & Limitations

| Component | Status | Details |
|---|---|---|
| **FastAPI Backend & Routers** | Fully functional | All endpoints operational under `/v1` |
| **Patient AI Companion Brain** | Fully functional | 7 intents, mood reassurance, repeated-question logging, and Ollama fallback |
| **Proactive Companion** | Fully functional | Morning greetings, gentle check-ins, evening wind-down, quiet hours |
| **Teach the Companion** | Fully functional | Prompt injection sanitization + instant SentenceTransformer FAISS embedding |
| **Conversation Review & Feedback**| Fully functional | Read-only logs + mark wrong feedback exclusion |
| **Caregiver Dashboard** | Fully functional | 7-day adherence, weekly bar chart, top questions, daily summary |
| **Face Engine & FAISS** | Fully functional | InsightFace buffalo_l + normalized 512-d index (never guesses below 0.38) |
| **Memory Retrieval** | Fully functional | Multilingual SentenceTransformers + FAISS |
| **Voice Transcription** | Fully functional | faster-whisper small int8 on CPU + VAD filter |
| **Demo Mode & Hidden Screen**| Fully functional | `/demo/reset`, `/demo/trigger-reminder`, long-press title dialog |
| **Offline Caching** | Fully functional | Local reminders & people cache prevents blank screens |
| **Emergency Alerts & SOS** | Fully functional | Intercepts keywords, creates alerts, informs family |
| **Free Calling Agent** | Fully functional | Rules-based SIM calling (`flutter_phone_direct_caller`), Telegram briefing, OpenRouter/Ollama wording |
| **Twilio Caregiver SMS** | Stubbed / Optional | Active when `FEATURE_SMS=true` with valid Twilio keys; replaced by free Telegram bot |
| **Push Notifications** | Stubbed | Active when `FEATURE_PUSH=true`; logs notification stub |
| **Punjabi TTS Voice** | Device dependent | Calls `pa-IN`; falls back gracefully to on-screen text display if device lacks Punjabi voice assets |

---

## Free Calling Agent Setup & Testing Guide

Ghajini 2.0 features a completely **free, zero-telephony-cost Calling Agent**. It does NOT require Twilio, cloud SIP trunks, or paid telephony subscriptions. Instead, it triggers native SIM phone calls directly from the patient's phone and delivers instant 3-line incident briefings to the caregiver via Telegram.

### 1. How It Works
1. **Rule-Based Decision**: Calls are triggered strictly by safety rules (never by an LLM):
   - SOS button pressed on Home or Companion screen.
   - Emergency voice phrase detected ("help", "madad", "fell", "bachao").
   - Critical medication reminder unacknowledged after `escalate_after_min`.
   - 2 missed check-ins.
2. **Safety Throttling**:
   - **Cooldown**: 2 minutes (120s) between call attempts.
   - **Hourly Limit**: Maximum 3 call attempts per hour per patient.
   - **Quiet Hours**: During 10:00 PM – 6:00 AM, routine calls are suppressed; only emergencies (`sos`, `emergency_phrase`) trigger calls.
3. **Contact Escalation**:
   - Contacts are evaluated in priority order (`is_emergency_contact == True`, sorted by `priority asc`).
   - If Contact #1 does not answer, the app asks *"Did Priya answer?"* and immediately offers Contact #2.
4. **Free AI Wording**:
   - A free model writes: (a) a soothing single-sentence patient reassurance message spoken via TTS, and (b) a 3-line caregiver briefing.
   - Supports local **Ollama** (`llama3.2:3b`) or **OpenRouter Free Tier** (models ending in `:free`).
   - **Privacy Guardrail**: If using OpenRouter, all patient and caregiver names and phone numbers are replaced with `[PATIENT]` and `[CAREGIVER]` before transmission and restored locally. Guaranteed fallback templates are used if the LLM is unavailable or hallucinates.

---

### 2. Setting Up Free Telegram Caregiver Alerts

1. **Create a Bot via BotFather**:
   - Open Telegram and search for `@BotFather`.
   - Send `/newbot`, choose a name (e.g., `GhajiniCaregiverBot`) and username (e.g., `my_ghajini_alert_bot`).
   - BotFather will give you a token like `7823456789:ABCdefGhIJKlmNoPQRstuVWxYz`.
2. **Get Your Telegram Chat ID**:
   - In Telegram, open your new bot and click **Start** (or send `/start`).
   - Search for `@userinfobot` on Telegram and send `/start`. It will reply with your numeric `Id` (e.g., `123456789`).
3. **Configure `.env`**:
   ```env
   FEATURE_TELEGRAM=true
   TELEGRAM_BOT_TOKEN="7823456789:ABCdefGhIJKlmNoPQRstuVWxYz"
   TELEGRAM_CHAT_ID="123456789"
   ```
4. **Test Without Placing a Call**:
   - In the Caregiver Portal under **Settings**, click **"Send Test Alert (No Phone Call)"** to verify instant Telegram delivery.

---

### 3. Choosing the LLM Provider (`ollama` vs `openrouter`)

- **Default (Local Ollama)**:
  ```env
  LLM_PROVIDER="ollama"
  OLLAMA_BASE_URL="http://localhost:11434"
  OLLAMA_MODEL="llama3.2:3b"
  ```
- **Optional Free Cloud (OpenRouter)**:
  1. Get a free API key at [openrouter.ai](https://openrouter.ai/keys).
  2. In `.env`:
     ```env
     LLM_PROVIDER="openrouter"
     OPENROUTER_API_KEY="sk-or-v1-..."
     OPENROUTER_MODEL="meta-llama/llama-3.2-3b-instruct:free"
     ```
  *(Note: Model ID must end with `:free`. Rate limit retries at most once, then uses fixed template fallbacks).*

---

### 4. Testing Calls on a Real Android Phone with a SIM

1. Connect your Android phone with USB debugging enabled:
   ```bash
   flutter devices
   ```
2. Run on device:
   ```bash
   cd frontend
   flutter run -d <device_id>
   ```
3. Tap **SOS** or **Call Family** on the Home screen:
   - The app asks for the `CALL_PHONE` permission on first use.
   - Speaks the soothing reassurance: *"I am calling Priya for you. Please stay right here."*
   - Shows a calm 5-second countdown window with a Cancel button.
   - Directly places the SIM phone call to the caregiver's number using `flutter_phone_direct_caller`.
   - When you return to the app, it prompts: *"Did Priya answer?"* with big Yes / No buttons. If No, it offers Contact #2.

---

### 5. What Works, What is Stubbed, and Limits

- **What Works**:
  - Direct native SIM calling on Android (`CALL_PHONE`).
  - Native iOS phone dialer confirmation (`tel:` URL scheme).
  - Web & desktop browser graceful fallback card (large phone display, Copy button, and Open Dialer button; never crashes).
  - Deterministic safety policy (max 3 calls/hour, 2-minute cool-down, quiet-hours suppression).
  - OpenRouter PII sanitization and desanitization.
  - Multi-tier emergency contact escalation (#1 Priya -> #2 Arun).
  - Free Telegram Bot API caregiver briefings.
- **Limits**:
  - **No Direct Calls on Web**: Web browsers cannot place direct cellular phone calls due to browser sandbox security; Ghajini provides a high-contrast card with an instant "Copy Number" and "Open Dialer" button.
  - **SIM Minutes**: Calls use the SIM card carrier's native minutes on the patient's phone; zero paid cloud telephony APIs are required.
  - **Video Room**: Public Jitsi rooms now require moderator authentication; `VIDEO_LINK_BASE_URL` is an optional setting and not required for core calling.
