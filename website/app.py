import os

from flask import Flask, render_template, redirect, url_for
from config import SECRET_KEY
from database import init_db

from modules.auth import auth_bp, login_required
from modules.dashboard import dashboard_bp
from modules.ssh import ssh_bp
from modules.xray import xray_bp
from modules.vps import vps_bp
from modules.services import services_bp


app = Flask(__name__)
app.secret_key = SECRET_KEY

app.config.update(
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE="Lax",
    SESSION_COOKIE_SECURE=os.environ.get(
        "PANEL_HTTPS", "0"
    ) == "1",
)

init_db()

app.register_blueprint(auth_bp)
app.register_blueprint(dashboard_bp)
app.register_blueprint(ssh_bp)
app.register_blueprint(xray_bp)
app.register_blueprint(vps_bp)
app.register_blueprint(services_bp)


@app.route("/")
def index():
    return redirect(url_for("dashboard.dashboard"))


@app.route("/health")
def health():
    return {
        "status": "ok",
        "panel": "AYAH ALMA PANEL",
    }, 200


@app.route("/vps/")
@login_required
def vps_page():
    from modules.vps import get_vps_stats

    return render_template(
        "vps.html",
        stats=get_vps_stats(),
    )


@app.route("/activity")
@login_required
def activity_page():
    from database import get_connection

    with get_connection() as conn:
        activities = conn.execute(
            """
            SELECT
                activity_logs.created_at,
                admins.username,
                activity_logs.action,
                activity_logs.details
            FROM activity_logs
            LEFT JOIN admins
                ON admins.id = activity_logs.admin_id
            ORDER BY activity_logs.id DESC
            LIMIT 100
            """
        ).fetchall()

    return render_template(
        "activity.html",
        activities=activities,
    )


@app.route("/admin")
@login_required
def admins_page():
    return render_template("admins.html")


@app.route("/services-page")
@login_required
def services_page():
    from modules.services import check_service

    services = {
        "ssh": check_service("ssh"),
        "xray": check_service("xray"),
        "nginx": check_service("nginx"),
        "haproxy": check_service("haproxy"),
    }

    return render_template(
        "services.html",
        services=services,
    )


if __name__ == "__main__":
    app.run(
        host="127.0.0.1",
        port=5000,
        debug=False,
    )
