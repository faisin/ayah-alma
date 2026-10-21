import subprocess

from flask import Blueprint, jsonify

from modules.auth import login_required


services_bp = Blueprint(
    "services",
    __name__,
    url_prefix="/services",
)


def check_service(service_name):
    try:
        result = subprocess.run(
            ["systemctl", "is-active", service_name],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )

        status = result.stdout.strip()

        if status == "active":
            return "ONLINE"

        if status == "inactive":
            return "OFFLINE"

        return status.upper() if status else "UNKNOWN"

    except (subprocess.SubprocessError, OSError):
        return "UNKNOWN"


@services_bp.route("/")
@login_required
def index():
    services = {
        "ssh": check_service("ssh"),
        "xray": check_service("xray"),
        "nginx": check_service("nginx"),
        "haproxy": check_service("haproxy"),
    }

    return jsonify(services)
