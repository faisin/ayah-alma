#!/bin/bash
set -Eeuo pipefail

echo "[INFO] Menyiapkan Nginx untuk instalasi sertifikat DNS-01 Cloudflare..."

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx curl wget

rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default

mkdir -p /etc/nginx/conf.d
mkdir -p /var/www/html/.well-known/acme-challenge

if [[ -f "./config/nginx.conf" ]]; then
    cp -f "./config/nginx.conf" /etc/nginx/nginx.conf
elif [[ -f "/root/ayah-alma/config/nginx.conf" ]]; then
    cp -f "/root/ayah-alma/config/nginx.conf" /etc/nginx/nginx.conf
else
    echo "[WARNING] config/nginx.conf not found; keeping package nginx.conf"
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

echo "[INFO] Nginx siap; validasi sertifikat dilakukan melalui DNS-01 Cloudflare."
