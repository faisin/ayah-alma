import psutil

from flask import Blueprint, render_template

from modules.auth import login_required


dashboard_bp = Blueprint("dashboard", __name__)


@dashboard_bp.route("/dashboard")
@login_required
def dashboard():
    cpu = psutil.cpu_percent(interval=0.5)
    memory = psutil.virtual_memory()
    disk = psutil.disk_usage("/")

    stats = {
        "cpu": cpu,
        "ram": memory.percent,
        "ram_used": round(memory.used / (1024 ** 3), 2),
        "ram_total": round(memory.total / (1024 ** 3), 2),
        "disk": disk.percent,
        "disk_used": round(disk.used / (1024 ** 3), 2),
        "disk_total": round(disk.total / (1024 ** 3), 2),
    }

    return render_template(
        "dashboard.html",
        stats=stats,
        admin_username=session.get("admin_username", "Admin"),
    )
