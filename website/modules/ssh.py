import subprocess

from flask import Blueprint, render_template

from modules.auth import login_required


ssh_bp = Blueprint("ssh", __name__, url_prefix="/ssh")


def get_ssh_status():
    try:
        result = subprocess.run(
            ["systemctl", "is-active", "ssh"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )

        status = result.stdout.strip()

        if status == "active":
            return "ONLINE"

        return "OFFLINE"

    except (subprocess.SubprocessError, OSError):
        return "UNKNOWN"


def get_ssh_port():
    try:
        result = subprocess.run(
            ["sshd", "-T"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )

        if result.returncode != 0:
            return "UNKNOWN"

        for line in result.stdout.splitlines():
            parts = line.split()

            if len(parts) == 2 and parts[0] == "port":
                return parts[1]

        return "UNKNOWN"

    except (subprocess.SubprocessError, OSError):
        return "UNKNOWN"


@ssh_bp.route("/")
@login_required
def index():
    ssh_info = {
        "status": get_ssh_status(),
        "port": get_ssh_port(),
        "accounts": [],
    }

    return render_template(
        "ssh/index.html",
        ssh=ssh_info,
    )
