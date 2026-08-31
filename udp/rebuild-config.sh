#!/bin/bash
# ==========================================
# REBUILD ZIVPN CONFIG - by Ayah Alma
# ==========================================

DB="/etc/zivpn/users.db"
CONFIG="/etc/zivpn/config.json"

# Ambil daftar user dari database dan format menjadi array JSON
if [[ -f "$DB" && -s "$DB" ]]; then
    USERS=$(awk '{print "\"" $1 "\""}' "$DB" | paste -sd "," -)
else
    USERS=""
fi

cat > "$CONFIG" <<EOF
{
  "listen": ":5667",
  "cert": "/etc/zivpn/zivpn.crt",
  "key": "/etc/zivpn/zivpn.key",
  "obfs": "zivpn",
  "auth": {
    "mode": "passwords",
    "config": [ $USERS ]
  }
}
EOF

# Restart service ZIVPN untuk menerapkan konfigurasi baru
systemctl restart zivpn
