#!/bin/bash
# Setup SSH WebSocket + UDPGW - by Ayah-Alma
# Converted for Ayah-Alma Project (Optimized & Fixed)

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

BASE_DIR="/root/ayah-alma"
DEPS_VERSION="deps-v2"
RELEASE_URL="https://github.com/faisin/ayah-alma/releases/download/${DEPS_VERSION}"

clear

echo -e "${GREEN}▶️ Installing SSH + WebSocket + UDP Custom...${NC}"
sleep 1

# ================= VALIDATION =================

if [[ ! -d "$BASE_DIR" ]]; then
    echo -e "${RED}[ERROR] Repo ayah-alma not found!${NC}"
    exit 1
fi

if [[ ! -f "$BASE_DIR/config/issue.net" ]]; then
    echo -e "${RED}[ERROR] issue.net not found in ayah-alma repository!${NC}"
    exit 1
fi

# ================= INSTALL DEPENDENCY =================

apt update -y
DEBIAN_FRONTEND=noninteractive apt install -y \
    openssh-server \
    stunnel4 \
    curl \
    wget \
    python3 \
    screen \
    git \
    golang-go \
    libtomcrypt1 \
    libtommath1 \
    dropbear

mkdir -p /usr/local/bin

# ================= INSTALL / CONFIGURE DROPBEAR =================

echo ""
echo -e "${GREEN}[INFO] Configuring Dropbear...${NC}"
echo ""

systemctl stop dropbear 2>/dev/null || true

# Konfigurasi port Dropbear (109 & 143)
cat > /etc/default/dropbear <<EOF
NO_START=0
DROPBEAR_PORT=109
DROPBEAR_EXTRA_ARGS="-p 143 -W 65536 -b /etc/issue.net"
DROPBEAR_RECEIVE_WINDOW=65536
EOF

# ================= HOSTKEY =================

mkdir -p /etc/dropbear

if [ ! -f /etc/dropbear/dropbear_rsa_host_key ]; then
    dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key >/dev/null 2>&1
fi

if [ ! -f /etc/dropbear/dropbear_ecdsa_host_key ]; then
    dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key >/dev/null 2>&1
fi

# ================= BANNER =================

cp "$BASE_DIR/config/issue.net" /etc/issue.net
chmod 644 /etc/issue.net

# ================= DROPBEAR SERVICE =================

cat > /etc/systemd/system/dropbear.service <<EOF
[Unit]
Description=Dropbear SSH Server
After=network.target

[Service]
ExecStart=/usr/sbin/dropbear -E -F -p 109 -p 143 -W 65536 -b /etc/issue.net
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# ================= BUILD GO WS =================

echo ""
echo -e "${GREEN}[INFO] Building Go WebSocket Services...${NC}"
echo ""

if ! command -v go >/dev/null 2>&1; then
    apt install -y golang-go
fi

if [ -d "$BASE_DIR/internal/go" ]; then
    cd "$BASE_DIR/internal/go" || true
    
    go build -ldflags="-s -w" -o /usr/local/bin/dropbearws ./dropbear-ws 2>/dev/null || {
        echo -e "${RED}[WARNING] Go build dropbearws skipped or failed, check source folder.${NC}"
    }
    
    go build -ldflags="-s -w" -o /usr/local/bin/stunnelws ./stunnel-ws 2>/dev/null || {
        echo -e "${RED}[WARNING] Go build stunnelws skipped or failed, check source folder.${NC}"
    }
    
    chmod +x /usr/local/bin/dropbearws 2>/dev/null || true
    chmod +x /usr/local/bin/stunnelws 2>/dev/null || true
fi

# Salin service WebSocket Go jika file servicenya ada
if [ -f "$BASE_DIR/internal/go/dropbear-ws.service" ]; then
    cp "$BASE_DIR/internal/go/dropbear-ws.service" /etc/systemd/system/dropbear-ws.service
fi

if [ -f "$BASE_DIR/internal/go/stunnel-ws.service" ]; then
    cp "$BASE_DIR/internal/go/stunnel-ws.service" /etc/systemd/system/stunnel-ws.service
fi

# ================= INSTALL BADVPN UDPGW =================

echo ""
echo -e "${GREEN}[INFO] Installing BadVPN UDPGW...${NC}"
echo ""

wget -qO /usr/local/bin/badvpn-udpgw "${RELEASE_URL}/badvpn-udpgw" || {
    echo -e "${RED}[WARNING] Failed to download binary from release, creating dummy/skipping...${NC}"
}

chmod +x /usr/local/bin/badvpn-udpgw 2>/dev/null || true

if [ -f "$BASE_DIR/sshws/udpgw.service" ]; then
    cp "$BASE_DIR/sshws/udpgw.service" /etc/systemd/system/
fi

# ================= INSTALL UDP CUSTOM =================

echo ""
echo -e "${GREEN}[INFO] Installing UDP Custom...${NC}"
echo ""

wget -qO /usr/local/bin/udp-custom "${RELEASE_URL}/udp-custom-linux-amd64" || {
    echo -e "${RED}[WARNING] Failed to download UDP Custom binary from release.${NC}"
}

chmod +x /usr/local/bin/udp-custom 2>/dev/null || true

mkdir -p /etc/udp-custom
if [ -f "$BASE_DIR/config/udp-cuatom.json" ]; then
    cp "$BASE_DIR/config/udp-cuatom.json" /etc/udp-custom/config.json
elif [ -f "$BASE_DIR/config/udp-custom.json" ]; then
    cp "$BASE_DIR/config/udp-custom.json" /etc/udp-custom/config.json
fi

if [ -f "$BASE_DIR/sshws/udp-custom.service" ]; then
    cp "$BASE_DIR/sshws/udp-custom.service" /etc/systemd/system/
fi

# ================= PERMISSION & SYSTEMD RELOAD =================

chmod 644 /etc/systemd/system/dropbear.service 2>/dev/null || true
chmod 644 /etc/systemd/system/dropbear-ws.service 2>/dev/null || true
chmod 644 /etc/systemd/system/stunnel-ws.service 2>/dev/null || true
chmod 644 /etc/systemd/system/udpgw.service 2>/dev/null || true
chmod 644 /etc/systemd/system/udp-custom.service 2>/dev/null || true

systemctl daemon-reload
systemctl daemon-reexec

# ================= ENABLE & START SERVICES =================

for svc in ssh dropbear dropbear-ws stunnel-ws udpgw udp-custom; do
    if systemctl list-unit-files | grep -q "^${svc}.service"; then
        systemctl enable "$svc" >/dev/null 2>&1
        systemctl restart "$svc" >/dev/null 2>&1
    fi
done

# ================= NOLOGIN WS ====================

cat > /etc/profile.d/no-login.sh <<'EOF'
#!/bin/bash
[[ "$USER" == "root" ]] && return
clear
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " SSH WS ACCOUNT ONLY"
echo " SHELL ACCESS DENIED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
sleep 2
pkill -9 -u "$USER"
EOF

chmod +x /etc/profile.d/no-login.sh

# ================= INSTALL LOG =================

cat >> /root/log-install.txt <<EOF

━━━━━━━━━━━━━━━━━━━━━━
SSH PANEL (AYAH-ALMA)
━━━━━━━━━━━━━━━━━━━━━━

OpenSSH             : 22
Dropbear            : 109,143
SSH Websocket       : 2082
SSH SSL Websocket   : 2096
BadVPN UDPGW        : 7300

━━━━━━━━━━━━━━━━━━━━━━

EOF

echo ""
echo -e "${GREEN}[ OK ] SSH + WS + UDPGW Installation Completed (Ayah-Alma)${NC}"
echo ""
