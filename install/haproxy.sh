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
if nginx -T 2>/dev/null | grep -E '^[[:space:]]*listen[[:space:]]+([^;]*:)?(80|443)([[:space:];]|$)' >/dev/null; then
    die 'Nginx masih memiliki listener port 80/443. Sisakan Nginx hanya pada 127.0.0.1:8080.'
fi
systemctl enable nginx >/dev/null
systemctl restart nginx || die 'Nginx fallback gagal berjalan.'

# Temporary HTTP-only HAProxy bootstrap. HAProxy remains the sole public port-80 owner;
# ACME HTTP-01 challenge files are served by the private Nginx backend.
cat > /etc/haproxy/haproxy.cfg <<'BOOTSTRAP_HAPROXY_EOF'
global
    log /dev/log local0
    user haproxy
    group haproxy
    daemon
    maxconn 100000

defaults
    mode http
    log global
    option httplog
    timeout connect 10s
    timeout client 1m
    timeout server 1m

frontend ayah_http_80
    bind :80
    bind :::80 v6only
    default_backend be_nginx_bootstrap

backend be_nginx_bootstrap
    server nginx 127.0.0.1:8080
BOOTSTRAP_HAPROXY_EOF
IPV6_DISABLED="$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null || echo 1)"
if [[ "$IPV6_DISABLED" != "0" ]]; then sed -i '/^[[:space:]]*bind :::80/d' /etc/haproxy/haproxy.cfg; fi
haproxy -c -f /etc/haproxy/haproxy.cfg || die 'Konfigurasi HAProxy bootstrap tidak valid.'
systemctl enable haproxy >/dev/null
systemctl restart haproxy || die 'HAProxy bootstrap gagal berjalan.'
info 'Nginx hanya mendengarkan 127.0.0.1:8080.'
info 'HAProxy bootstrap aktif pada port publik 80 untuk validasi ACME; final 80/443 dipasang oleh install/xray.sh.'
