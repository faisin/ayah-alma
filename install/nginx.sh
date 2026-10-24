#!/bin/bash
set -Eeuo pipefail

echo "[INFO] Menyiapkan Nginx untuk bootstrap sebelum sertifikat HTTP-01 Standalone..."

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx libnginx-mod-stream curl wget

rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default

mkdir -p /etc/nginx/conf.d /etc/nginx/streams-enabled
mkdir -p /var/www/html/.well-known/acme-challenge


if [[ -f "./config/nginx.conf" ]]; then
    cp -f "./config/nginx.conf" /etc/nginx/nginx.conf
elif [[ -f "/root/ayah-alma/config/nginx.conf" ]]; then
    cp -f "/root/ayah-alma/config/nginx.conf" /etc/nginx/nginx.conf
else
    echo "[WARNING] config/nginx.conf not found; keeping package nginx.conf"
fi

# Enable the Nginx stream context for raw TCP/TLS passthrough routes.
if ! grep -Eq '^[[:space:]]*stream[[:space:]]*\{' /etc/nginx/nginx.conf; then
    if grep -Eq '^[[:space:]]*http[[:space:]]*\{' /etc/nginx/nginx.conf; then
        sed -i '/^[[:space:]]*http[[:space:]]*{/i stream {\n    include /etc/nginx/streams-enabled/*.conf;\n}\n' /etc/nginx/nginx.conf
    else
        echo "[ERROR] Tidak menemukan blok http {} pada /etc/nginx/nginx.conf."
        exit 1
    fi
fi

# Jangan memuat konfigurasi TLS final sebelum sertifikat tersedia.
rm -f /etc/nginx/conf.d/xray.conf

cat > /etc/nginx/conf.d/acme-bootstrap.conf <<'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name _;

    root /var/www/html;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/html;
        default_type text/plain;
        try_files $uri =404;
    }

    location / {
        return 404;
    }
}
EOF

chmod 755 /var/www/html
chmod 755 /var/www/html/.well-known
chmod 755 /var/www/html/.well-known/acme-challenge

nginx -t
systemctl enable nginx
systemctl restart nginx
sleep 2

if ! systemctl is-active --quiet nginx; then
    echo "[ERROR] Nginx bootstrap failed."
    systemctl status nginx --no-pager || true
    exit 1
fi

echo "[INFO] Nginx bootstrap siap. Nginx akan dihentikan sementara oleh install/xray.sh saat validasi HTTP-01 Standalone."
