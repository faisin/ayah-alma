import time

import psutil

from flask import Blueprint, jsonify

from modules.auth import login_required


vps_bp = Blueprint("vps", __name__, url_prefix="/vps")


def get_vps_stats():
    memory = psutil.virtual_memory()
    disk = psutil.disk_usage("/")
    network = psutil.net_io_counters()

    return {
        "hostname": __import__("socket").gethostname(),
        "cpu_percent": psutil.cpu_percent(interval=0.5),
        "cpu_count": psutil.cpu_count() or 0,
        "ram": {
            "percent": memory.percent,
            "used_gb": round(memory.used / (1024 ** 3), 2),
            "total_gb": round(memory.total / (1024 ** 3), 2),
        },
        "disk": {
            "percent": disk.percent,
            "used_gb": round(disk.used / (1024 ** 3), 2),
            "total_gb": round(disk.total / (1024 ** 3), 2),
        },
        "network": {
            "bytes_sent": network.bytes_sent,
            "bytes_recv": network.bytes_recv,
        },
        "uptime_seconds": int(time.time() - psutil.boot_time()),
    }


@vps_bp.route("/stats")
@login_required
def stats():
    return jsonify(get_vps_stats())
