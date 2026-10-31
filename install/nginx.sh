#!/bin/bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
apt-get update -y
apt-get install -y nginx
install -d -m 755 /var/www/ayah-alma /etc/nginx/sites-available /etc/nginx/sites-enabled
install -m 644 "$SCRIPT_DIR/config/nginx-fallback.conf" /etc/nginx/sites-available/ayah-alma-fallback
if [[ -s "$SCRIPT_DIR/config/www/index.html" ]]; then install -m 644 "$SCRIPT_DIR/config/www/index.html" /var/www/ayah-alma/index.html; fi
rm -f /etc/nginx/sites-enabled/default
ln -sfn /etc/nginx/sites-available/ayah-alma-fallback /etc/nginx/sites-enabled/ayah-alma-fallback
nginx -t
if nginx -T 2>/dev/null | grep -E '^[[:space:]]*listen[[:space:]]+([^;]*:)?(80|443)([[:space:];]|$)' >/dev/null; then
    echo '[ERROR] Nginx masih memiliki listener port 80/443; gunakan hanya 127.0.0.1:8080.' >&2
    exit 1
fi
systemctl enable nginx
systemctl restart nginx
echo '[OK] Nginx hanya mendengarkan 127.0.0.1:8080; port publik 80/443 milik HAProxy.'
