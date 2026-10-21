from flask import Flask, render_template
from config import SECRET_KEY
from database import init_db

app = Flask(__name__)
app.secret_key = SECRET_KEY

init_db()


@app.route("/")
def index():
    return render_template("dashboard.html")


@app.route("/health")
def health():
    return {"status": "ok", "panel": "AYAH ALMA PANEL"}, 200


if __name__ == "__main__":
    app.run(
        host="127.0.0.1",
        port=5000,
        debug=False
    )
