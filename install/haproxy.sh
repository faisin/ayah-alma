#!/bin/bash
set -Eeuo pipefail

info(){ printf '[INFO] %s\n' "$*"; }
warn(){ printf '[PERINGATAN] %s\n' "$*"; }
die(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# HAProxy terminates/routes public TCP traffic. Nginx is only a loopback fallback.
systemctl stop haproxy >/dev/null 2>&1 || true
systemctl stop nginx >/dev/null 2>&1 || true

apt-get update -y
apt-get install -y haproxy nginx curl wget lsof ca-certificates openssl

mkdir -p /etc/haproxy/certs /etc/nginx/sites-available /etc/nginx/sites-enabled /var/www/ayah-alma

[[ -s "$SCRIPT_DIR/config/nginx-fallback.conf" ]] || die 'config/nginx-fallback.conf tidak ditemukan.'
install -m 644 "$SCRIPT_DIR/config/nginx-fallback.conf" /etc/nginx/sites-available/ayah-alma-fallback
if [[ -s "$SCRIPT_DIR/config/www/index.html" ]]; then
    install -m 644 "$SCRIPT_DIR/config/www/index.html" /var/www/ayah-alma/index.html
fi
rm -f /etc/nginx/sites-enabled/default /etc/nginx/conf.d/xray.conf /etc/nginx/conf.d/acme-bootstrap.conf
ln -sfn /etc/nginx/sites-available/ayah-alma-fallback /etc/nginx/sites-enabled/ayah-alma-fallback

nginx -t || die 'Konfigurasi Nginx fallback tidak valid.'
systemctl enable nginx >/dev/null
systemctl restart nginx || die 'Nginx fallback gagal berjalan.'

# HAProxy is enabled but not started until install/xray.sh provisions the TLS cert.
systemctl enable haproxy >/dev/null 2>&1 || true
info 'Nginx fallback aktif hanya pada 127.0.0.1:8080.'
info 'HAProxy siap dipasang; listener publik akan aktif setelah sertifikat dan konfigurasi final tersedia.'
