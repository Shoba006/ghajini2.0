import os
from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict

os.environ["HF_HUB_OFFLINE"] = os.environ.get("HF_HUB_OFFLINE", "1")
os.environ["TRANSFORMERS_OFFLINE"] = os.environ.get("TRANSFORMERS_OFFLINE", "1")


class Settings(BaseSettings):
    PROJECT_NAME: str = "Ghajini 2.0"
    API_V1_STR: str = "/v1"
    DATABASE_URL: str = "sqlite:///./ghajini.db"

    # Face engine thresholds
    FACE_T_HIGH: float = 0.50
    FACE_T_LOW: float = 0.38

    # Ollama settings
    OLLAMA_BASE_URL: str = "http://localhost:11434"
    OLLAMA_MODEL: str = "llama3.2:3b"
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
    DATA_DIR: str = "./data"
    UPLOAD_DIR: str = "./data/uploads"

    # Default patient ID for single-patient mode
    DEFAULT_PATIENT_ID: int = 1

    model_config = SettingsConfigDict(
        env_file=[".env", "backend/.env", str(Path(__file__).resolve().parent.parent.parent / ".env")],
        env_file_encoding="utf-8",
        extra="ignore"
    )

    def init_directories(self) -> None:
        try:
            Path(self.DATA_DIR).mkdir(parents=True, exist_ok=True)
            Path(self.UPLOAD_DIR).mkdir(parents=True, exist_ok=True)
        except OSError:
            pass


settings = Settings()
