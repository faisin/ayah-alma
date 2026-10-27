#!/bin/bash
# ==========================================
# AYAH-ALMA UDP ZIVPN INSTALLER
# ==========================================

clear

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}     INSTALL UDP ZIVPN${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

sleep 1

# ==============================
# CHECK ROOT
# ==============================

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Please run as root!${NC}"
   exit 1
fi

# ==============================
# UPDATE SYSTEM
# ==============================

echo -e "${YELLOW}[*] Updating system...${NC}"

apt-get update -y

# ==============================
# INSTALL DEPENDENCIES
# ==============================

echo -e "${YELLOW}[*] Installing dependencies...${NC}"

apt-get install -y \
wget \
curl \
openssl \
net-tools \
ufw >/dev/null 2>&1

# ==============================
# STOP OLD SERVICE
# ==============================

systemctl stop zivpn >/dev/null 2>&1

# ==============================
# INSTALL VENDORED BINARY
# ==============================

echo -e "${YELLOW}[*] Setting up ZIVPN binary...${NC}"
ARCH="$(dpkg --print-architecture 2>/dev/null || true)"
case "$ARCH" in
    amd64|arm64) ;;
    *) echo -e "${RED}Unsupported architecture: $ARCH${NC}"; exit 1 ;;
esac
ZIVPN_BIN="$SCRIPT_DIR/bin/$ARCH/zivpn"
if [[ ! -f "$ZIVPN_BIN" ]]; then
    echo -e "${RED}Vendored ZIVPN binary not found: $ZIVPN_BIN${NC}"
    exit 1
fi
file "$ZIVPN_BIN" | grep -q 'ELF' || { echo -e "${RED}ZIVPN binary is not a valid ELF executable!${NC}"; exit 1; }
install -m 755 "$ZIVPN_BIN" /usr/local/bin/zivpn

# ==============================
# CHECK BINARY
# ==============================

if [[ ! -f /usr/local/bin/zivpn ]]; then
    echo -e "${RED}Failed setting up binary!${NC}"
    exit 1
fi

# ==============================
# CHECK PORT
# ==============================

if ss -lunp | grep -q ":5667"; then
    echo -e "${RED}Port 5667 already in use!${NC}"
    exit 1
fi

# ==============================
# CREATE DIRECTORY
# ==============================

echo -e "${YELLOW}[*] Creating directory...${NC}"

mkdir -p /etc/zivpn

# ==============================
# CREATE USERS DB
# ==============================

if [[ -s /etc/zivpn/users.db ]]; then
    echo -e "${GREEN}[INFO] Database pengguna ZiVPN yang sudah ada dipertahankan.${NC}"
else
    initial_password="$(openssl rand -hex 12)"
    printf '%s\n' "$initial_password" > /etc/zivpn/users.db
    chmod 600 /etc/zivpn/users.db
    printf '%s\n' "$initial_password" > /root/zivpn-initial-password.txt
    chmod 600 /root/zivpn-initial-password.txt
    if [[ -w /dev/tty ]]; then
        printf '[PENTING] Password ZiVPN awal: %s\nSimpan password ini. Salinan root-only: /root/zivpn-initial-password.txt\n' "$initial_password" > /dev/tty
    else
        echo -e "${YELLOW}[PENTING] Password ZiVPN disimpan di /root/zivpn-initial-password.txt (izin 600).${NC}"
    fi
fi

# ==============================
# GENERATE SSL CERTIFICATE
# ==============================

echo -e "${YELLOW}[*] Generating SSL certificate...${NC}"

openssl req -new -newkey rsa:4096 \
-days 3650 \
-nodes \
-x509 \
-subj "/C=ID/ST=Jakarta/L=Jakarta/O=AyahAlma/OU=UDP/CN=zivpn" \
-keyout /etc/zivpn/zivpn.key \
-out /etc/zivpn/zivpn.crt >/dev/null 2>&1

# ==============================
# GENERATE CONFIG
# ==============================

echo -e "${YELLOW}[*] Generating config...${NC}"

USERS=$(awk '{print "\"" $1 "\""}' /etc/zivpn/users.db | paste -sd "," -)

cat > /etc/zivpn/config.json <<EOF
{
  "listen": ":5667",
  "cert": "/etc/zivpn/zivpn.crt",
  "key": "/etc/zivpn/zivpn.key",
  "obfs": "zivpn",
  "auth": {
    "mode": "passwords",
    "config": [ $USERS ]
  }
}
EOF

# ==============================
# SYSTEM OPTIMIZATION
# ==============================

echo -e "${YELLOW}[*] Optimizing UDP buffer...${NC}"

sysctl -w net.core.rmem_max=16777216 >/dev/null
sysctl -w net.core.wmem_max=16777216 >/dev/null

grep -q "net.core.rmem_max" /etc/sysctl.conf || \
echo "net.core.rmem_max=16777216" >> /etc/sysctl.conf

grep -q "net.core.wmem_max" /etc/sysctl.conf || \
echo "net.core.wmem_max=16777216" >> /etc/sysctl.conf

sysctl -p >/dev/null 2>&1

# ==============================
# CREATE SYSTEMD SERVICE
# ==============================

echo -e "${YELLOW}[*] Creating service...${NC}"

cat > /etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=zivpn VPN Server (Ayah-Alma)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info

[Install]
WantedBy=multi-user.target
EOF

# ==============================
# IPTABLES RULE
# ==============================

echo -e "${YELLOW}[*] Setting iptables rules...${NC}"

iptables -t nat -C PREROUTING \
-p udp --dport 6000:19999 \
-j REDIRECT --to-ports 5667 2>/dev/null || \
iptables -t nat -A PREROUTING \
-p udp --dport 6000:19999 \
-j REDIRECT --to-ports 5667

# ==============================
# SAVE IPTABLES
# ==============================

echo -e "${YELLOW}[*] Saving iptables rules...${NC}"

DEBIAN_FRONTEND=noninteractive \
apt-get install -y iptables-persistent >/dev/null 2>&1

netfilter-persistent save >/dev/null 2>&1

# ==============================
# ENABLE SERVICE
# ==============================

echo -e "${YELLOW}[*] Starting service...${NC}"

systemctl daemon-reload
systemctl enable zivpn >/dev/null 2>&1
systemctl restart zivpn

sleep 2

# ==============================
# CHECK SERVICE
# ==============================

if systemctl is-active --quiet zivpn; then
    STATUS="${GREEN}RUNNING${NC}"
else
    STATUS="${RED}FAILED${NC}"
fi

# ==============================
# INSTALL LOG
# ==============================

touch /root/log-install.txt
grep -q "ZiVPN" /root/log-install.txt || \
echo "ZiVPN (Ayah-Alma)  : 5667 UDP" >> /root/log-install.txt

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}      ZIVPN INSTALLED${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " Service Status : $STATUS"
echo -e " UDP Port       : 5667"
echo -e " Config Path    : /etc/zivpn/config.json"
echo -e " Users DB       : /etc/zivpn/users.db"
echo -e " Authentication  : password-based (see /etc/zivpn/users.db)"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
