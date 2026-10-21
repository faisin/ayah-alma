from functools import wraps

from flask import (
    Blueprint,
    render_template,
    request,
    redirect,
    url_for,
    session,
    flash,
)

from werkzeug.security import check_password_hash

from database import get_connection, log_activity


auth_bp = Blueprint("auth", __name__)


def login_required(view):
    @wraps(view)
    def wrapped_view(*args, **kwargs):
        if "admin_id" not in session:
            return redirect(url_for("auth.login"))

        return view(*args, **kwargs)

    return wrapped_view


@auth_bp.route("/login", methods=["GET", "POST"])
def login():
    if "admin_id" in session:
        return redirect(url_for("index"))

    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "")

        if not username or not password:
            flash("Username dan password wajib diisi.", "error")
            return render_template("login.html")

        with get_connection() as conn:
            admin = conn.execute(
                """
                SELECT id, username, password_hash
                FROM admins
                WHERE username = ?
                """,
                (username,),
            ).fetchone()

        if admin and check_password_hash(
            admin["password_hash"], password
        ):
            session.clear()
            session["admin_id"] = admin["id"]
            session["admin_username"] = admin["username"]

            log_activity(
                admin["id"],
                "LOGIN",
                "Admin berhasil login",
            )

            return redirect(url_for("index"))

        flash("Username atau password salah.", "error")

    return render_template("login.html")


@auth_bp.route("/logout", methods=["POST"])
@login_required
def logout():
    admin_id = session.get("admin_id")

    log_activity(
        admin_id,
        "LOGOUT",
        "Admin keluar dari panel",
    )

    session.clear()

    return redirect(url_for("auth.login"))
