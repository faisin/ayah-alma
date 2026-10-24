#!/bin/bash
set -Eeuo pipefail

echo "[INFO] Menyiapkan Nginx untuk bootstrap sertifikat..."

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx libnginx-mod-stream curl wget

mkdir -p /etc/nginx/conf.d
mkdir -p /etc/nginx/streams-enabled
mkdir -p /etc/nginx/modules-enabled
mkdir -p /var/www/html/.well-known/acme-challenge

# Gunakan konfigurasi Nginx dari repository jika tersedia.
if [[ -f "./config/nginx.conf" ]]; then
    cp -f "./config/nginx.conf" /etc/nginx/nginx.conf
elif [[ -f "/root/ayah-alma/config/nginx.conf" ]]; then
    cp -f "/root/ayah-alma/config/nginx.conf" /etc/nginx/nginx.conf
else
    echo "[WARNING] config/nginx.conf tidak ditemukan; menggunakan konfigurasi yang tersedia."
fi

# Pastikan modul Stream tersedia.
STREAM_MODULE="/usr/lib/nginx/modules/ngx_stream_module.so"

if [[ ! -f "$STREAM_MODULE" ]]; then
    echo "[ERROR] Modul Nginx Stream tidak ditemukan: $STREAM_MODULE"
    exit 1
fi

# Muat modul sebelum blok konfigurasi stream {} diproses.
if ! grep -RqsE '^[[:space:]]*load_module[[:space:]].*ngx_stream_module\.so[[:space:]]*;' \
    /etc/nginx/nginx.conf /etc/nginx/modules-enabled 2>/dev/null; then
    sed -i "1i load_module $STREAM_MODULE;" /etc/nginx/nginx.conf
fi

# Pastikan blok Stream tersedia dan membaca konfigurasi rute TCP.
if ! grep -Eq '^[[:space:]]*stream[[:space:]]*\{' /etc/nginx/nginx.conf; then
    if grep -Eq '^[[:space:]]*http[[:space:]]*\{' /etc/nginx/nginx.conf; then
        sed -i '/^[[:space:]]*http[[:space:]]*{/i stream {\n    include /etc/nginx/streams-enabled/*.conf;\n}\n' /etc/nginx/nginx.conf
    else
        echo "[ERROR] Blok http {} tidak ditemukan di nginx.conf."
        exit 1
    fi
fi

# Jangan memuat konfigurasi TLS final sebelum sertifikat tersedia.
rm -f /etc/nginx/conf.d/xray.conf

# Konfigurasi bootstrap HTTP untuk validasi sertifikat.
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

echo "[INFO] Menguji konfigurasi Nginx..."

if ! nginx -t; then
    echo "[ERROR] Konfigurasi Nginx tidak valid. Nginx tidak direstart."
    exit 1
fi

systemctl enable nginx
systemctl restart nginx
sleep 2

if ! systemctl is-active --quiet nginx; then
    echo "[ERROR] Nginx gagal berjalan."
    systemctl status nginx --no-pager || true
    exit 1
fi

echo "[INFO] Nginx bootstrap berhasil disiapkan."
