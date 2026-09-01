#!/bin/bash
# Setup SSH WebSocket + UDPGW - by Ayah-Alma
# Converted for Ayah-Alma Project (Optimized & Fixed)

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

clear

echo -e "${GREEN}▶️ Installing SSH + WebSocket + UDP Custom...${NC}"
sleep 1

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

cat > /etc/default/dropbear <<EOF
NO_START=0
DROPBEAR_PORT=109
DROPBEAR_EXTRA_ARGS="-p 143 -W 65536 -b /etc/issue.net"
DROPBEAR_RECEIVE_WINDOW=65536
EOF

mkdir -p /etc/dropbear

if [ ! -f /etc/dropbear/dropbear_rsa_host_key ]; then
    dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key >/dev/null 2>&1
fi

if [ ! -f /etc/dropbear/dropbear_ecdsa_host_key ]; then
    dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key >/dev/null 2>&1
fi

# AMBIL ISSUE.NET DARI BERBAGAI ALTERNATIF DIREKTORI
if [ -f "./config/issue.net" ]; then
    cp ./config/issue.net /etc/issue.net
elif [ -f "/root/ayah-alma/config/issue.net" ]; then
    cp /root/ayah-alma/config/issue.net /etc/issue.net
else
    echo "Server SSH Ayah-Alma" > /etc/issue.net
fi
chmod 644 /etc/issue.net

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

# Tentukan base direktori secara dinamis
if [ -d "./internal/go" ]; then
    GO_DIR="./internal/go"
elif [ -d "/root/ayah-alma/internal/go" ]; then
    GO_DIR="/root/ayah-alma/internal/go"
else
    GO_DIR=""
fi

if [ -n "$GO_DIR" ]; then
    cd "$GO_DIR" || true
    
    go build -ldflags="-s -w" -o /usr/local/bin/dropbearws ./dropbear-ws 2>/dev/null || true
    go build -ldflags="-s -w" -o /usr/local/bin/stunnelws ./stunnel-ws 2>/dev/null || true
    
    chmod +x /usr/local/bin/dropbearws 2>/dev/null || true
    chmod +x /usr/local/bin/stunnelws 2>/dev/null || true
    cd - >/dev/null
fi

if [ -f "$GO_DIR/dropbear-ws.service" ]; then
    cp "$GO_DIR/dropbear-ws.service" /etc/systemd/system/dropbear-ws.service
elif [ -f "sshws/ws-dropbear.service" ]; then
    cp sshws/ws-dropbear.service /etc/systemd/system/dropbear-ws.service
fi

if [ -f "$GO_DIR/stunnel-ws.service" ]; then
    cp "$GO_DIR/stunnel-ws.service" /etc/systemd/system/stunnel-ws.service
elif [ -f "sshws/ws-stunnel.service" ]; then
    cp sshws/ws-stunnel.service /etc/systemd/system/stunnel-ws.service
fi

# ================= INSTALL BADVPN UDPGW =================

echo ""
echo -e "${GREEN}[INFO] Installing BadVPN UDPGW...${NC}"
echo ""

if [ -f "./bin/badvpn-udpgw" ]; then
    cp ./bin/badvpn-udpgw /usr/local/bin/badvpn-udpgw
    chmod +x /usr/local/bin/badvpn-udpgw
elif [ -f "/root/ayah-alma/bin/badvpn-udpgw" ]; then
    cp /root/ayah-alma/bin/badvpn-udpgw /usr/local/bin/badvpn-udpgw
    chmod +x /usr/local/bin/badvpn-udpgw
fi

if [ -f "sshws/udpgw.service" ]; then
    cp sshws/udpgw.service /etc/systemd/system/
elif [ -f "/root/ayah-alma/sshws/udpgw.service" ]; then
    cp /root/ayah-alma/sshws/udpgw.service /etc/systemd/system/
fi

# ================= INSTALL UDP CUSTOM =================

echo ""
echo -e "${GREEN}[INFO] Installing UDP Custom...${NC}"
echo ""

if [ -f "./bin/udp-custom" ]; then
    cp ./bin/udp-custom /usr/local/bin/udp-custom
    chmod +x /usr/local/bin/udp-custom
elif [ -f "/root/ayah-alma/bin/udp-custom" ]; then
    cp /root/ayah-alma/bin/udp-custom /usr/local/bin/udp-custom
    chmod +x /usr/local/bin/udp-custom
fi

mkdir -p /etc/udp-custom
if [ -f "./config/udp-custom.json" ]; then
    cp ./config/udp-custom.json /etc/udp-custom/config.json
elif [ -f "/root/ayah-alma/config/udp-custom.json" ]; then
    cp /root/ayah-alma/config/udp-custom.json /etc/udp-custom/config.json
elif [ -f "./config/udp-cuatom.json" ]; then
    cp ./config/udp-cuatom.json /etc/udp-custom/config.json
fi

if [ -f "sshws/udp-custom.service" ]; then
    cp sshws/udp-custom.service /etc/systemd/system/
elif [ -f "/root/ayah-alma/sshws/udp-custom.service" ]; then
    cp /root/ayah-alma/sshws/udp-custom.service /etc/systemd/system/
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

touch /root/log-install.txt
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
