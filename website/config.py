import os
from pathlib import Path
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent

load_dotenv(BASE_DIR / ".env")

DATA_DIR = BASE_DIR / "data"
LOG_DIR = BASE_DIR / "logs"

DATA_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)

DATABASE_PATH = DATA_DIR / "panel.db"

SECRET_KEY = os.environ.get("PANEL_SECRET_KEY")

if not SECRET_KEY:
    raise RuntimeError(
        "PANEL_SECRET_KEY belum diatur. Periksa file .env."
    )

HOST = os.environ.get("PANEL_HOST", "127.0.0.1")
PORT = int(os.environ.get("PANEL_PORT", "5000"))

DEBUG = False
