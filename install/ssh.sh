#!/bin/bash
# Setup SSH WebSocket + UDPGW - by Ayah-Alma
# Converted for Ayah-Alma Project (Optimized & Fixed)

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

clear

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

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
if [ -f "$SCRIPT_DIR/config/issue.net" ]; then
    cp "$SCRIPT_DIR/config/issue.net" /etc/issue.net
else
    echo -e "${RED}[ERROR] config/issue.net tidak ditemukan.${NC}"
    exit 1
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
GO_DIR="$SCRIPT_DIR/internal/go"
[ -d "$GO_DIR/dropbear-ws" ] || { echo -e "${RED}[ERROR] dropbear-ws source tidak ditemukan.${NC}"; exit 1; }
[ -d "$GO_DIR/stunnel-ws" ] || { echo -e "${RED}[ERROR] stunnel-ws source tidak ditemukan.${NC}"; exit 1; }

( cd "$GO_DIR" && go build -ldflags="-s -w" -o /usr/local/bin/dropbearws ./dropbear-ws )
( cd "$GO_DIR" && go build -ldflags="-s -w" -o /usr/local/bin/stunnelws ./stunnel-ws )
chmod +x /usr/local/bin/dropbearws /usr/local/bin/stunnelws
[ -x /usr/local/bin/dropbearws ] || exit 1
[ -x /usr/local/bin/stunnelws ] || exit 1

[ -f "$GO_DIR/dropbear-ws.service" ] || { echo -e "${RED}[ERROR] dropbear-ws.service tidak ditemukan.${NC}"; exit 1; }
cp "$GO_DIR/dropbear-ws.service" /etc/systemd/system/dropbear-ws.service
[ -f "$GO_DIR/stunnel-ws.service" ] || { echo -e "${RED}[ERROR] stunnel-ws.service tidak ditemukan.${NC}"; exit 1; }
cp "$GO_DIR/stunnel-ws.service" /etc/systemd/system/stunnel-ws.service

# ================= INSTALL BADVPN UDPGW =================

echo ""
echo -e "${GREEN}[INFO] Installing BadVPN UDPGW...${NC}"
echo ""

ARCH="$(dpkg --print-architecture 2>/dev/null || true)"
BADVPN_BIN="$SCRIPT_DIR/bin/$ARCH/badvpn-udpgw"
[ -f "$BADVPN_BIN" ] || { echo -e "${RED}[ERROR] Binary badvpn-udpgw tidak ditemukan: $BADVPN_BIN${NC}"; exit 1; }
file "$BADVPN_BIN" | grep -q 'ELF' || { echo -e "${RED}[ERROR] badvpn-udpgw bukan ELF valid.${NC}"; exit 1; }
install -m 755 "$BADVPN_BIN" /usr/local/bin/badvpn-udpgw

[ -f "$SCRIPT_DIR/sshws/udpgw.service" ] || { echo -e "${RED}[ERROR] udpgw.service tidak ditemukan.${NC}"; exit 1; }
cp "$SCRIPT_DIR/sshws/udpgw.service" /etc/systemd/system/


# ================= INSTALL UDP CUSTOM =================

echo ""
echo -e "${GREEN}[INFO] Installing UDP Custom...${NC}"
echo ""

UDP_BIN="$SCRIPT_DIR/bin/$ARCH/udp-custom"
[ -f "$UDP_BIN" ] || { echo -e "${RED}[ERROR] Binary udp-custom tidak ditemukan: $UDP_BIN${NC}"; exit 1; }
file "$UDP_BIN" | grep -q 'ELF' || { echo -e "${RED}[ERROR] udp-custom bukan ELF valid.${NC}"; exit 1; }
install -m 755 "$UDP_BIN" /usr/local/bin/udp-custom

mkdir -p /etc/udp-custom
[ -f "$SCRIPT_DIR/config/udp-custom.json" ] || { echo -e "${RED}[ERROR] config/udp-custom.json tidak ditemukan.${NC}"; exit 1; }
cp "$SCRIPT_DIR/config/udp-custom.json" /etc/udp-custom/config.json

[ -f "$SCRIPT_DIR/sshws/udp-custom.service" ] || { echo -e "${RED}[ERROR] udp-custom.service tidak ditemukan.${NC}"; exit 1; }
cp "$SCRIPT_DIR/sshws/udp-custom.service" /etc/systemd/system/

# ================= PERMISSION & SYSTEMD RELOAD =================

chmod 644 /etc/systemd/system/dropbear.service 2>/dev/null || true
chmod 644 /etc/systemd/system/dropbear-ws.service 2>/dev/null || true
chmod 644 /etc/systemd/system/stunnel-ws.service 2>/dev/null || true
chmod 644 /etc/systemd/system/udpgw.service 2>/dev/null || true
chmod 644 /etc/systemd/system/udp-custom.service 2>/dev/null || true

systemctl daemon-reload

# ================= ENABLE & START SERVICES =================

for svc in ssh dropbear dropbear-ws stunnel-ws udpgw udp-custom; do
    if systemctl list-unit-files | grep -q "^${svc}.service"; then
        systemctl enable "$svc" >/dev/null 2>&1
        systemctl restart "$svc" >/dev/null 2>&1
    fi
done

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
