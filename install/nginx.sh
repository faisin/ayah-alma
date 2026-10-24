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

# Gunakan konfigurasi dari repository jika tersedia.
if [[ -f "./config/nginx.conf" ]]; then
    cp -f "./config/nginx.conf" /etc/nginx/nginx.conf
elif [[ -f "/root/ayah-alma/config/nginx.conf" ]]; then
    cp -f "/root/ayah-alma/config/nginx.conf" /etc/nginx/nginx.conf
fi

NGINX_CONF="/etc/nginx/nginx.conf"
STREAM_MODULE="/usr/lib/nginx/modules/ngx_stream_module.so"
STREAM_MODULE_CONF="/etc/nginx/modules-enabled/50-mod-stream.conf"

# Pastikan file modul Stream tersedia.
if [[ ! -f "$STREAM_MODULE" ]]; then
    echo "[ERROR] Modul Stream tidak ditemukan: $STREAM_MODULE"
    exit 1
fi

# Pastikan modul dimuat oleh konfigurasi Nginx yang aktif.
if grep -Eq '^[[:space:]]*load_module[[:space:]].*ngx_stream_module\.so[[:space:]]*;' "$NGINX_CONF"; then
    echo "[INFO] Direktif load_module Stream sudah ada di nginx.conf."

elif grep -Fq '/etc/nginx/modules-enabled/*.conf' "$NGINX_CONF"; then
    echo "[INFO] nginx.conf menyertakan modules-enabled."

    if ! grep -RqsE '^[[:space:]]*load_module[[:space:]].*ngx_stream_module\.so[[:space:]]*;' /etc/nginx/modules-enabled 2>/dev/null; then
        printf 'load_module %s;\n' "$STREAM_MODULE" > "$STREAM_MODULE_CONF"
    fi

else
    echo "[INFO] Menambahkan pemuatan modul Stream ke nginx.conf."
    sed -i "1i load_module $STREAM_MODULE;" "$NGINX_CONF"
fi

# Pastikan blok stream tersedia.
if ! grep -Eq '^[[:space:]]*stream[[:space:]]*\{' "$NGINX_CONF"; then
    if grep -Eq '^[[:space:]]*http[[:space:]]*\{' "$NGINX_CONF"; then
        sed -i '/^[[:space:]]*http[[:space:]]*{/i stream {\n    include /etc/nginx/streams-enabled/*.conf;\n}\n' "$NGINX_CONF"
    else
        echo "[ERROR] Tidak menemukan blok http {} di $NGINX_CONF."
        exit 1
    fi
fi

# Jangan memuat konfigurasi TLS final sebelum sertifikat tersedia.
rm -f /etc/nginx/conf.d/xray.conf

# Konfigurasi HTTP sementara untuk bootstrap sertifikat.
cat > /etc/nginx/conf.d/acme-bootstrap.conf <<'BOOTSTRAP_EOF'
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
BOOTSTRAP_EOF

chmod 755 /var/www/html
chmod 755 /var/www/html/.well-known
chmod 755 /var/www/html/.well-known/acme-challenge

echo "[INFO] Menguji konfigurasi Nginx..."

if ! nginx -t; then
    echo "[ERROR] Konfigurasi Nginx tidak valid. Nginx tidak direstart."
    exit 1
fi

echo "[INFO] Konfigurasi Nginx valid."

systemctl enable nginx
systemctl restart nginx
sleep 2

if ! systemctl is-active --quiet nginx; then
    echo "[ERROR] Nginx gagal berjalan."
    systemctl status nginx --no-pager || true
    exit 1
fi

echo "[INFO] Nginx bootstrap berhasil disiapkan."
