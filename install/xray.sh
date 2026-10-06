#!/bin/bash
# Setup Xray Core + Nginx Reverse Proxy - by Ayah-Alma
# Converted for Ayah-Alma Project

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

clear

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${GREEN}▶️ Installing Xray Core...${NC}"
sleep 1

# ================= VALIDATION =================

if ! command -v nginx >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] NGINX not installed!${NC}"
    echo -e "${RED}Run install/nginx.sh first${NC}"
    exit 1
fi

# ================= INSTALL DEPENDENCY =================

apt update -y

apt install -y \
curl wget cron jq unzip haproxy \
gnupg coreutils lsof qrencode \
ca-certificates

# Validate HAProxy installation from Debian/Ubuntu package
command -v haproxy >/dev/null 2>&1 || { echo -e "${RED}[ERROR] HAProxy package not available after install.${NC}"; exit 1; }

mkdir -p /etc/xray
mkdir -p /var/log/xray
mkdir -p /usr/local/bin

# ================= INSTALL VENDORED XRAY =================

echo -e "${GREEN}⬇️ Installing vendored Xray Core...${NC}"

ARCH="$(dpkg --print-architecture 2>/dev/null || true)"
case "$ARCH" in
    amd64|arm64) ;;
    *) echo -e "${RED}[ERROR] Unsupported architecture: $ARCH${NC}"; exit 1 ;;
esac
XRAY_BIN="$SCRIPT_DIR/bin/$ARCH/xray"
if [[ ! -f "$XRAY_BIN" ]]; then
    echo -e "${RED}[ERROR] Vendored Xray binary not found: $XRAY_BIN${NC}"
    exit 1
fi
file "$XRAY_BIN" | grep -q 'ELF' || { echo -e "${RED}[ERROR] Xray binary is not a valid ELF executable.${NC}"; exit 1; }
install -m 755 "$XRAY_BIN" /usr/local/bin/xray
/usr/local/bin/xray version >/dev/null 2>&1 || { echo -e "${RED}[ERROR] Xray binary failed validation.${NC}"; exit 1; }

# ================= DOMAIN =================

if [[ -f /root/domain ]]; then
    domain=$(cat /root/domain)
elif [[ -f /etc/xray/domain ]]; then
    domain=$(cat /etc/xray/domain)
else
    echo -e "${RED}[ERROR] File domain not found!${NC}"
    exit 1
fi

echo "$domain" > /etc/xray/domain

raw_domain="$domain"
vmess_domain="$domain"
vless_domain="$domain"
trojan_domain="$domain"

echo "$domain" > /etc/xray/raw-domain
echo "$domain" > /etc/xray/vmess-domain
echo "$domain" > /etc/xray/vless-domain
echo "$domain" > /etc/xray/trojan-domain

# ================= ENABLE CRON =================

systemctl enable cron
systemctl restart cron

# ================= INSTALL ACME =================

if [ ! -f ~/.acme.sh/acme.sh ]; then
    echo -e "${GREEN}🔐 Menginstall acme.sh...${NC}"
    curl https://get.acme.sh | sh -s email=admin@$domain
fi

chmod +x ~/.acme.sh/acme.sh

~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
~/.acme.sh/acme.sh --register-account -m admin@$domain || true

# ================= ACME WEBROOT =================

echo -e "${GREEN}📁 Preparing ACME webroot...${NC}"

mkdir -p /var/www/html/.well-known/acme-challenge


# ================= ISSUE CERT =================

mkdir -p /var/www/html/.well-known/acme-challenge

~/.acme.sh/acme.sh \
    --issue \
    -d "$domain" \
    --webroot /var/www/html \
    --keylength ec-256 \
    --force || {
        echo -e "${RED}[ERROR] Failed to issue SSL certificate!${NC}"
        exit 1
}

# ================= INSTALL CERT =================

mkdir -p /etc/xray

~/.acme.sh/acme.sh \
    --install-cert \
    -d "$domain" \
    --ecc \
    --key-file /etc/xray/private.key \
    --fullchain-file /etc/xray/cert.crt \
    --reloadcmd "true" || {
        echo -e "${RED}[ERROR] Failed to install certificate!${NC}"
        exit 1
}

# ================= PERMISSION =================

chmod 600 /etc/xray/private.key
chmod 644 /etc/xray/cert.crt

# ================= FINAL NGINX TLS CONFIG =================

# Bootstrap owns port 80 only during ACME. Remove it before final config.
rm -f /etc/nginx/conf.d/acme-bootstrap.conf
cp "$SCRIPT_DIR/config/xray.conf" /etc/nginx/conf.d/xray.conf
chmod 644 /etc/nginx/conf.d/xray.conf

echo -e "${GREEN}🧪 Testing final NGINX TLS configuration...${NC}"
nginx -t || {
    echo -e "${RED}[ERROR] Invalid final NGINX configuration!${NC}"
    exit 1
}

systemctl restart nginx
sleep 2

if ! systemctl is-active --quiet nginx; then
    echo -e "${RED}[ERROR] NGINX failed to start with final TLS configuration!${NC}"
    journalctl -u nginx -n 30 --no-pager
    exit 1
fi

if ! ss -lnt | grep -qE '127\.0\.0\.1:8443|\[::1\]:8443'; then
    echo "[ERROR] Nginx backend :8443 is not listening after final config."
    ss -lntp | grep -E ':80|:8443' || true
    exit 1
fi

# ================= 443 TLS MULTIPLEXER =================

mkdir -p /etc/haproxy
sed -e "s/vmess\.DOMAIN/${vmess_domain}/g" \
    -e "s/vless\.DOMAIN/${vless_domain}/g" \
    -e "s/trojan\.DOMAIN/${trojan_domain}/g" \
    "$SCRIPT_DIR/config/haproxy.cfg" > /etc/haproxy/haproxy.cfg

if [ ! -s /etc/haproxy/haproxy.cfg ]; then
    echo "[ERROR] Failed to create HAProxy config"
    exit 1
fi

haproxy -c -f /etc/haproxy/haproxy.cfg || {
    echo "[ERROR] Invalid HAProxy config"
    exit 1
}

systemctl enable haproxy
systemctl restart haproxy
sleep 2

if ! systemctl is-active --quiet haproxy; then
    echo -e "${RED}[ERROR] HAProxy failed to start!${NC}"
    journalctl -u haproxy -n 30 --no-pager
    exit 1
fi

# ================= XRAY CONFIG =================

cp "$SCRIPT_DIR/config/xray.json" /etc/xray/config.json
chmod 644 /etc/xray/config.json

# ================= XRAY SERVICE =================

cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
Documentation=https://xray.dev/
After=network.target nss-lookup.target

[Service]
User=root
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray -config /etc/xray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# ================= TEST CONFIG =================

echo -e "${GREEN}🧪 Testing NGINX Config...${NC}" 

nginx -t || { 
    echo -e "${RED}[ERROR] Invalid NGINX configuration!${NC}" 
    exit 1 
} 

echo -e "${GREEN}🧪 Testing XRAY Config...${NC}" 
xray -test -config /etc/xray/config.json || { 
    echo -e "${RED}[ERROR] Invalid XRAY configuration!${NC}" 
    exit 1 
}

# ================= START SERVICE =================

systemctl daemon-reload
systemctl daemon-reexec

systemctl enable xray nginx haproxy
systemctl restart xray
systemctl restart nginx
systemctl restart haproxy

sleep 2 

if ! systemctl is-active --quiet xray; then 
    echo -e "${RED}[ERROR] XRAY failed to start!${NC}" 
    journalctl -u xray -n 20 --no-pager 
    exit 1 
fi 

if ! systemctl is-active --quiet haproxy; then
    echo -e "${RED}[ERROR] HAProxy failed to start!${NC}"
    journalctl -u haproxy -n 20 --no-pager
    exit 1
fi

if ! systemctl is-active --quiet nginx; then 
    echo -e "${RED}[ERROR] NGINX failed to start!${NC}" 
    journalctl -u nginx -n 20 --no-pager 
    exit 1 
fi

# ================= INSTALL LOG =================

touch /root/log-install.txt
cat >> /root/log-install.txt <<EOF

━━━━━━━━━━━━━━━━━━━━━━
XRAY PANEL (AYAH-ALMA)
━━━━━━━━━━━━━━━━━━━━━━

XRAY VMess TLS      : 443
XRAY VMess None TLS : 80
XRAY VMess gRPC     : 443

XRAY VLESS TLS      : 443
XRAY VLESS None TLS : 80
XRAY VLESS gRPC     : 443

XRAY Trojan TLS     : 443
XRAY Trojan gRPC    : 443

XRAY SS WS TLS      : 443
XRAY SS WS None TLS : 80
XRAY SS WS gRPC     : 443

━━━━━━━━━━━━━━━━━━━━━━

EOF

# ================= DONE =================

clear

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ XRAY INSTALLED SUCCESSFULLY${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "Domain        : ${domain}
Raw TLS SNI   : ${vmess_domain}, ${vless_domain}, ${trojan_domain}"
echo -e "XRAY Config   : /etc/xray/config.json"
echo -e "NGINX Config  : /etc/nginx/conf.d/xray.conf"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
