import asyncio
import logging
import os
import time
from contextlib import asynccontextmanager
from urllib.parse import urlparse
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
import httpx

from app.core.config import settings
from app.db.models import Memory, PersonFace
from app.db.mongo import HAS_MOTOR, AsyncIOMotorClient, mongo_manager
from app.db.session import SessionLocal, init_db
from app.modules.alerts.router import router as alerts_router
from app.modules.calls.router import router as calls_router
from app.modules.cardiolife.router import router as cardiolife_router
from app.modules.chat.llm_client import ollama_client
from app.modules.chat.router import router as chat_router
from app.modules.companion.router import router as companion_router
from app.modules.dashboard.router import router as dashboard_router
from app.modules.dashboard.web import get_dashboard_html
from app.modules.demo.router import router as demo_router
from app.modules.faces.engine import face_engine
from app.modules.integrations.router import router as integrations_router
from app.modules.memory.retrieval import memory_retrieval
from app.modules.memory.router import router as memory_router
from app.modules.people.router import router as people_router
from app.modules.privacy.router import router as privacy_router
from app.modules.reminders.router import router as reminders_router
from app.modules.reminders.scheduler import start_scheduler, stop_scheduler
from app.modules.voice.router import router as voice_router
from app.modules.voice.transcriber import voice_transcriber

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


def preload_indices() -> None:
    """Preloads database faces and memories into FAISS on startup."""
    db = SessionLocal()
    try:
        # Load faces into FAISS
        faces = db.query(PersonFace).all()
        face_records = [(f.id, f.person_id, f.embedding_json) for f in faces if f.embedding_json]
        face_engine.load_from_db(face_records)
        logger.info(f"Loaded {len(face_records)} faces into FAISS index.")

        # Load memories into FAISS
        memories = db.query(Memory).all()
        memory_records = [(m.id, m.text, m.embedding_json) for m in memories]
        memory_retrieval.load_from_db(memory_records)
        logger.info(f"Loaded {len(memory_records)} memories into FAISS index.")
    except Exception as e:
        logger.error(f"Error preloading indices: {e}")
    finally:
        db.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup with timing and full model warm-up
    t0 = time.time()
    logger.info("Starting Ghajini 2.0 backend...")
    is_serverless = bool(os.environ.get("VERCEL") or os.environ.get("AWS_LAMBDA_FUNCTION_NAME"))
    try:
        settings.init_directories()
    except Exception as e:
        logger.warning(f"Directory initialization notice: {e}")
    try:
        init_db()
    except Exception as e:
        logger.warning(f"Database initialization notice: {e}")
    try:
        await mongo_manager.init()
    except Exception as e:
        logger.warning(f"Mongo initialization notice: {e}")
    try:
        preload_indices()
    except Exception as e:
        logger.warning(f"Indices preload notice: {e}")
    try:
        voice_transcriber.load()
    except Exception as e:
        logger.warning(f"Transcriber load notice: {e}")

    if not is_serverless and not os.environ.get("PYTEST_CURRENT_TEST") and not os.environ.get("TESTING"):
        try:
            start_scheduler()
        except Exception as e:
            logger.warning(f"Scheduler start notice: {e}")

    # Pre-warm Ollama if not running in pytest or test mode
    if not is_serverless and not os.environ.get("PYTEST_CURRENT_TEST") and not os.environ.get("TESTING"):
        try:
            await asyncio.wait_for(ollama_client.generate_answer("hello", ["hello"]), timeout=5.0)
            logger.info("Ollama LLM warm-up completed successfully.")
        except Exception as e:
            logger.info(f"Ollama warm-up note: {e}")

    warmup_duration = round(time.time() - t0, 3)
    logger.info(f"All components preloaded and warmed up in {warmup_duration} seconds.")
    yield
    # Shutdown
    logger.info("Shutting down Ghajini 2.0 backend...")
    if not is_serverless:
        try:
            stop_scheduler()
        except Exception:
            pass


app = FastAPI(
    title=settings.PROJECT_NAME,
    description="AI memory companion for Alzheimer's patients",
    version="2.0.0",
    lifespan=lifespan,
)

# CORS enabled for all origins in dev
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/dashboard", response_class=HTMLResponse, tags=["dashboard"])
@app.get("/", response_class=HTMLResponse, tags=["dashboard"])
def serve_caregiver_dashboard():
    """Serves the interactive web-based Caregiver Dashboard."""
    return get_dashboard_html()


@app.get("/logo.png", tags=["dashboard"])
@app.get("/static/logo.png", tags=["dashboard"])
def get_logo():
    """Serves the transparent logo PNG."""
    from fastapi.responses import FileResponse, Response
    import base64
    logo_path = os.path.join(os.path.dirname(__file__), "static", "logo.png")
    if os.path.exists(logo_path):
        return FileResponse(logo_path, media_type="image/png")
    try:
        from app.static.logo_data import LOGO_BASE64
        return Response(content=base64.b64decode(LOGO_BASE64), media_type="image/png")
    except Exception:
        return Response(status_code=404)


@app.get("/health")
@app.get(f"{settings.API_V1_STR}/health")
async def health_check():
    """
    Comprehensive health check reporting status of:
    - Primary Database (SQLAlchemy SQLite)
    - Document Store (MongoDB Motor / Embedded JSON Document Engine)
    - Ollama LLM
    - Face engine
    - Whisper voice engine
    """
    # 1. Primary Database check (SQLAlchemy)
    db_status = "connected"
    try:
        from sqlalchemy import text
        from app.db.session import engine
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
    except Exception as e:
        db_status = f"disconnected: {e}"

    # 2. MongoDB / Document Store check
    mongo_status = "connected"
    mongo_engine = "embedded document engine"
    if not os.environ.get("PYTEST_CURRENT_TEST") and not os.environ.get("TESTING"):
        if mongo_manager._connected:
            mongo_status = "connected"
            mongo_engine = "motor"
        else:
            # Check if live MongoDB has become available
            if HAS_MOTOR and AsyncIOMotorClient is not None:
                try:
                    kwargs = {"serverSelectionTimeoutMS": 1000}
                    try:
                        import certifi
                        if "mongodb+srv://" in settings.MONGODB_URL:
                            kwargs["tlsCAFile"] = certifi.where()
                    except ImportError:
                        pass
                    test_client = AsyncIOMotorClient(settings.MONGODB_URL, **kwargs)
                    await asyncio.wait_for(test_client.admin.command("ping"), timeout=1.5)
                    mongo_manager._motor_client = test_client
                    mongo_manager._connected = True
                    mongo_status = "connected"
                    mongo_engine = "motor"
                except Exception:
                    mongo_status = "connected"
                    mongo_engine = "embedded document engine"

    # 3. Ollama check
    ollama_status = "unavailable"
    if not os.environ.get("PYTEST_CURRENT_TEST") and not os.environ.get("TESTING"):
        try:
            async with httpx.AsyncClient(timeout=1.0) as client:
                res = await client.get(f"{settings.OLLAMA_BASE_URL}/api/tags")
                if res.status_code == 200:
                    ollama_status = "available"
        except Exception:
            ollama_status = "unavailable"

    # 4. Model statuses
    face_status = "loaded" if face_engine.app is not None or face_engine.index is not None else "fallback"
    whisper_status = "loaded" if voice_transcriber.model is not None else "fallback"

    return {
        "status": "healthy",
        "app": settings.PROJECT_NAME,
        "version": "2.0.0",
        "database": db_status,
        "database_url": settings.DATABASE_URL,
        "mongo": mongo_status,
        "mongo_engine": mongo_engine,
        "ollama": ollama_status,
        "face_model": face_status,
        "whisper_model": whisper_status,
        "face_engine_loaded": face_status == "loaded",
    }


# Include Routers under /v1
v1_prefix = settings.API_V1_STR
app.include_router(people_router, prefix=f"{v1_prefix}/people", tags=["people"])
# Direct /recognize endpoint under /v1 as specified
app.add_api_route(
    f"{v1_prefix}/recognize",
    endpoint=people_router.routes[-1].endpoint,
    methods=["POST"],
    response_model=people_router.routes[-1].response_model,
    tags=["recognition"],
)
app.include_router(memory_router, prefix=f"{v1_prefix}/memories", tags=["memory"])
app.include_router(chat_router, prefix=v1_prefix, tags=["chat"])  # contains /v1/ask
app.include_router(voice_router, prefix=f"{v1_prefix}/voice", tags=["voice"])
app.include_router(alerts_router, prefix=f"{v1_prefix}/alerts", tags=["alerts"])
app.include_router(reminders_router, prefix=f"{v1_prefix}/reminders", tags=["reminders"])
app.include_router(privacy_router, prefix=f"{v1_prefix}/privacy", tags=["privacy"])
app.include_router(dashboard_router, prefix=f"{v1_prefix}/dashboard", tags=["dashboard"])
app.include_router(companion_router, prefix=f"{v1_prefix}/companion", tags=["companion"])
app.include_router(calls_router, prefix=f"{v1_prefix}/calls", tags=["calls"])
app.include_router(cardiolife_router, prefix=f"{v1_prefix}/cardiolife", tags=["cardiolife"])
app.include_router(demo_router, prefix=f"{v1_prefix}/demo", tags=["demo"])
app.include_router(integrations_router, prefix=f"{v1_prefix}/integrations", tags=["integrations"])
