#!/bin/bash
# Setup Xray Core + Nginx Reverse Proxy - by Ayah-Alma
# Converted for Ayah-Alma Project

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

clear

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
curl wget cron jq unzip \
gnupg coreutils lsof qrencode \
ca-certificates

mkdir -p /etc/xray
mkdir -p /var/log/xray
mkdir -p /usr/local/bin

# ================= DOWNLOAD XRAY =================

echo -e "${GREEN}⬇️ Downloading Xray Core...${NC}"

mkdir -p /tmp/xray

wget -qO /tmp/xray.zip \
"https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip" || { 
    echo -e "${RED}[ERROR] Failed to download Xray Core!${NC}" 
    exit 1 
}

unzip -o /tmp/xray.zip -d /tmp/xray

install -m 755 /tmp/xray/xray /usr/local/bin/xray

rm -rf /tmp/xray
rm -f /tmp/xray.zip

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

# ================= STOP PORT 80 =================

echo -e "${GREEN}🛑 Freeing Port 80...${NC}"

systemctl stop nginx 2>/dev/null || true
systemctl stop apache2 2>/dev/null || true

fuser -k 80/tcp >/dev/null 2>&1 || true

# ================= ISSUE CERT =================

echo -e "${GREEN}🚀 Issuing SSL Certificate...${NC}"

~/.acme.sh/acme.sh \
    --issue \
    -d "$domain" \
    --standalone \
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
    --fullchain-file /etc/xray/cert.crt || {
        echo -e "${RED}[ERROR] Failed to install certificate!${NC}"
        exit 1
}

# ================= PERMISSION =================

chmod 600 /etc/xray/private.key
chmod 644 /etc/xray/cert.crt

# ================= XRAY CONFIG =================

if [ -f "./config/xray.json" ]; then
    cp ./config/xray.json /etc/xray/config.json
elif [ -f "/root/ayah-alma/config/xray.json" ]; then
    cp /root/ayah-alma/config/xray.json /etc/xray/config.json
fi

if [ -f "./config/xray.conf" ]; then
    cp ./config/xray.conf /etc/nginx/conf.d/xray.conf
elif [ -f "/root/ayah-alma/config/xray.conf" ]; then
    cp /root/ayah-alma/config/xray.conf /etc/nginx/conf.d/xray.conf
fi

chmod 644 /etc/xray/config.json 2>/dev/null || true
chmod 644 /etc/nginx/conf.d/xray.conf 2>/dev/null || true

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

systemctl enable xray
systemctl restart xray
systemctl restart nginx

sleep 2 

if ! systemctl is-active --quiet xray; then 
    echo -e "${RED}[ERROR] XRAY failed to start!${NC}" 
    journalctl -u xray -n 20 --no-pager 
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

echo -e "Domain        : ${domain}"
echo -e "XRAY Config   : /etc/xray/config.json"
echo -e "NGINX Config  : /etc/nginx/conf.d/xray.conf"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
