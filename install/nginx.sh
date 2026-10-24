#!/bin/bash
set -Eeuo pipefail

echo "[INFO] Menyiapkan Nginx untuk bootstrap AYAH ALMA..."

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx libnginx-mod-stream curl wget

# Pastikan direktori konfigurasi tersedia.
mkdir -p /etc/nginx/conf.d
mkdir -p /etc/nginx/streams-enabled
mkdir -p /var/www/html/.well-known/acme-challenge
mkdir -p /etc/nginx/modules-enabled

# Muat modul Stream jika tersedia sebagai modul dinamis Ubuntu.
STREAM_MODULE="/usr/lib/nginx/modules/ngx_stream_module.so"
STREAM_LOADED=false

if nginx -V 2>&1 | grep -q -- '--with-stream'; then
    echo "[INFO] Stream tersedia secara built-in."
    STREAM_LOADED=true
elif [[ -f "$STREAM_MODULE" ]]; then
    if ! grep -RqsE '^[[:space:]]*load_module[[:space:]]+.*ngx_stream_module\.so' \
        /etc/nginx/nginx.conf /etc/nginx/modules-enabled 2>/dev/null; then
        printf 'load_module %s;\n' "$STREAM_MODULE" \
            > /etc/nginx/modules-enabled/50-mod-stream.conf
    fi
    STREAM_LOADED=true
else
    echo "[ERROR] Modul Nginx Stream tidak ditemukan: $STREAM_MODULE"
    exit 1
fi

# Gunakan konfigurasi repository bila tersedia.
if [[ -f "./config/nginx.conf" ]]; then
    cp -f "./config/nginx.conf" /etc/nginx/nginx.conf
elif [[ -f "/root/ayah-alma/config/nginx.conf" ]]; then
    cp -f "/root/ayah-alma/config/nginx.conf" /etc/nginx/nginx.conf
else
    echo "[INFO] Mempertahankan konfigurasi nginx.conf yang tersedia."
fi

# Pastikan stream context disediakan sebelum blok http.
if ! grep -Eq '^[[:space:]]*stream[[:space:]]*\{' /etc/nginx/nginx.conf; then
    if grep -Eq '^[[:space:]]*http[[:space:]]*\{' /etc/nginx/nginx.conf; then
        sed -i '/^[[:space:]]*http[[:space:]]*{/i stream {\n    include /etc/nginx/streams-enabled/*.conf;\n}\n' \
            /etc/nginx/nginx.conf
    else
        echo "[ERROR] Tidak menemukan blok http {} pada nginx.conf."
        exit 1
    fi
fi

# Hindari konfigurasi TLS Xray sebelum sertifikat siap.
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

# Uji konfigurasi terlebih dahulu agar error tidak tersembunyi.
echo "[INFO] Menguji konfigurasi Nginx..."
if ! nginx -t; then
    echo "[ERROR] Konfigurasi Nginx tidak valid. Nginx tidak direstart."
    exit 1
fi

systemctl enable nginx
systemctl restart nginx
sleep 2

if ! systemctl is-active --quiet nginx; then
    echo "[ERROR] Nginx bootstrap gagal aktif."
    systemctl status nginx --no-pager || true
    exit 1
fi

echo "[INFO] Nginx bootstrap berhasil aktif."
