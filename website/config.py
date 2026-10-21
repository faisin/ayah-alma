import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent

DATA_DIR = BASE_DIR / "data"
LOG_DIR = BASE_DIR / "logs"

DATABASE_PATH = DATA_DIR / "panel.db"

SECRET_KEY = os.environ.get("PANEL_SECRET_KEY")

HOST = os.environ.get("PANEL_HOST", "127.0.0.1")
PORT = int(os.environ.get("PANEL_PORT", "5000"))

DEBUG = False
