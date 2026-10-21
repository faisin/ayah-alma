import json
import subprocess

from flask import Blueprint, render_template

from modules.auth import login_required


xray_bp = Blueprint("xray", __name__, url_prefix="/xray")


def get_xray_status():
    try:
        result = subprocess.run(
            ["systemctl", "is-active", "xray"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )

        return (
            "ONLINE"
            if result.stdout.strip() == "active"
            else "OFFLINE"
        )

    except (subprocess.SubprocessError, OSError):
        return "UNKNOWN"


def get_xray_config_path():
    candidates = [
        "/usr/local/etc/xray/config.json",
        "/etc/xray/config.json",
    ]

    for path in candidates:
        try:
            with open(path, "r", encoding="utf-8") as file:
                json.load(file)
            return path
        except (OSError, json.JSONDecodeError):
            continue

    return None


@xray_bp.route("/")
@login_required
def index():
    config_path = get_xray_config_path()

    xray_info = {
        "status": get_xray_status(),
        "config_available": config_path is not None,
        "config_path": config_path or "Tidak ditemukan",
    }

    return render_template(
        "xray/index.html",
        xray=xray_info,
    )
