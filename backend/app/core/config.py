import os
from pathlib import Path
from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

os.environ["HF_HUB_OFFLINE"] = os.environ.get("HF_HUB_OFFLINE", "1")
os.environ["TRANSFORMERS_OFFLINE"] = os.environ.get("TRANSFORMERS_OFFLINE", "1")

# Project / repository root directory (4 levels up from this file: backend/app/core/config.py)
REPO_ROOT: Path = Path(__file__).resolve().parent.parent.parent.parent


class Settings(BaseSettings):
    PROJECT_NAME: str = "Ghajini 2.0"
    API_V1_STR: str = "/v1"
    DATABASE_URL: str = f"sqlite:///{REPO_ROOT / 'ghajini.db'}"

    # Face engine thresholds
    FACE_T_HIGH: float = 0.50
    FACE_T_LOW: float = 0.38

    # Ollama settings
    OLLAMA_BASE_URL: str = "http://localhost:11434"
    OLLAMA_MODEL: str = "tinyllama:latest"
    OLLAMA_TEMPERATURE: float = 0.2
    OLLAMA_MAX_TOKENS: int = 120
    OLLAMA_TIMEOUT_SECONDS: float = 15.0

    # Whisper settings
    WHISPER_MODEL: str = "small"

    # Feature flags & Alerts
    FEATURE_PUSH: bool = False
    FEATURE_SMS: bool = False
    TWILIO_ACCOUNT_SID: str = ""
    TWILIO_AUTH_TOKEN: str = ""
    TWILIO_FROM_NUMBER: str = ""
    CAREGIVER_PHONE: str = "+919123507478"

    # LLM Provider Switch (Ollama / OpenRouter Free Tier)
    LLM_PROVIDER: str = "ollama"  # "ollama" | "openrouter"
    OPENROUTER_API_KEY: str = ""
    OPENROUTER_MODEL: str = "meta-llama/llama-3.2-3b-instruct:free"

    # Caregiver Telegram Briefing Channel
    FEATURE_TELEGRAM: bool = False
    TELEGRAM_BOT_TOKEN: str = ""
    TELEGRAM_CHAT_ID: str = ""

    # Optional Video Room
    VIDEO_LINK_BASE_URL: str = ""  # e.g. "https://meet.jit.si"

    # OmniDimension (OmniDim) Calling Provider
    OMNIDIM_API_KEY: str = ""
    OMNIDIM_BASE_URL: str = "https://omnidim.io/api/v1"
    OMNIDIM_AGENT_ID: str = ""
    OMNIDIM_FROM_NUMBER_ID: str = ""
    OMNIDIM_WEBHOOK_URL: str = ""

    # Call Limits
    CALL_MAX_PER_HOUR: int = 3
    CALL_COOLDOWN_SECONDS: int = 120  # 2 minutes

    # Privacy controls
    STORE_PHOTOS: bool = False  # Do not store raw recognition photos unless true

    # Demo Mode & MongoDB
    DEMO_MODE: bool = True
    MONGODB_URL: str = "mongodb://localhost:27017"

    # Reminder & Escalation settings
    ESCALATE_AFTER_MIN: int = 10
    QUIET_HOURS_START: int = 22  # 10:00 PM
    QUIET_HOURS_END: int = 6    # 06:00 AM

    # Data directories
    DATA_DIR: str = str(REPO_ROOT / "data")
    UPLOAD_DIR: str = str(REPO_ROOT / "data" / "uploads")

    # Default patient ID for single-patient mode
    DEFAULT_PATIENT_ID: int = 1

    model_config = SettingsConfigDict(
        env_file=[
            str(REPO_ROOT / ".env"),
            str(REPO_ROOT / "backend" / ".env"),
            ".env",
            "backend/.env",
        ],
        env_file_encoding="utf-8",
        extra="ignore"
    )

    @model_validator(mode="after")
    def resolve_relative_paths(self) -> "Settings":
        """Ensures SQLite and storage paths resolve to project root regardless of working directory."""
        if self.DATABASE_URL.startswith("sqlite:///"):
            raw_path = self.DATABASE_URL[len("sqlite:///"):]
            if not os.path.isabs(raw_path):
                clean_path = raw_path[2:] if raw_path.startswith("./") else raw_path
                self.DATABASE_URL = f"sqlite:///{(REPO_ROOT / clean_path).resolve()}"

        if not os.path.isabs(self.DATA_DIR):
            clean_data = self.DATA_DIR[2:] if self.DATA_DIR.startswith("./") else self.DATA_DIR
            self.DATA_DIR = str((REPO_ROOT / clean_data).resolve())

        if not os.path.isabs(self.UPLOAD_DIR):
            clean_upload = self.UPLOAD_DIR[2:] if self.UPLOAD_DIR.startswith("./") else self.UPLOAD_DIR
            self.UPLOAD_DIR = str((REPO_ROOT / clean_upload).resolve())

        return self

    def init_directories(self) -> None:
        try:
            Path(self.DATA_DIR).mkdir(parents=True, exist_ok=True)
            Path(self.UPLOAD_DIR).mkdir(parents=True, exist_ok=True)
        except OSError:
            pass


settings = Settings()
