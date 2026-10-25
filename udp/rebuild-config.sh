#!/bin/bash
set -Eeuo pipefail

DB="/etc/zivpn/users.db"
CONFIG="/etc/zivpn/config.json"
TMP="$(mktemp /etc/zivpn/config.json.XXXXXX)"
trap 'rm -f "$TMP"' EXIT

[[ -f "$DB" ]] || { echo "[ERROR] Database pengguna tidak ditemukan: $DB" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "[ERROR] Python 3 tidak ditemukan." >&2; exit 1; }

python3 - "$DB" "$TMP" <<'PYCONFIG'
import json
import sys
from pathlib import Path

db = Path(sys.argv[1])
out = Path(sys.argv[2])
users = []
seen = set()
for line in db.read_text(errors="replace").splitlines():
    fields = line.split()
    if not fields:
        continue
    username = fields[0]
    if username not in seen:
        users.append(username)
        seen.add(username)

config = {
    "listen": ":5667",
    "cert": "/etc/zivpn/zivpn.crt",
    "key": "/etc/zivpn/zivpn.key",
    "obfs": "zivpn",
    "auth": {
        "mode": "passwords",
        "config": users,
    },
}
out.write_text(json.dumps(config, indent=2) + "\n")
PYCONFIG

chmod 600 "$TMP"
install -m 600 "$TMP" "$CONFIG"
trap - EXIT
rm -f "$TMP"

if systemctl is-active --quiet zivpn 2>/dev/null; then
    systemctl restart zivpn || { echo "[ERROR] Gagal memulai ulang ZiVPN." >&2; exit 1; }
fi

echo "[INFO] Konfigurasi ZiVPN diperbarui dari $DB."
