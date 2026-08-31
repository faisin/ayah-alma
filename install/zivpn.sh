#!/bin/bash
# ==========================================
# AYAH-ALMA UDP ZIVPN INSTALLER
# ==========================================

clear

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

BASE_DIR="/root/ayah-alma"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}     INSTALL UDP ZIVPN${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

sleep 1

# ==============================
# CHECK ROOT & REPO
# ==============================

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Please run as root!${NC}"
   exit 1
fi

if [[ ! -d "$BASE_DIR" ]]; then
    echo -e "${RED}[ERROR] Repo ayah-alma not found!${NC}"
    exit 1
fi

# ==============================
# UPDATE SYSTEM
# ==============================

echo -e "${YELLOW}[*] Updating system...${NC}"

apt-get update -y
apt-get upgrade -y

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
# DOWNLOAD BINARY
# ==============================

echo -e "${YELLOW}[*] Downloading ZIVPN binary...${NC}"

wget -q -O /usr/local/bin/zivpn \
https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64[span_4](start_span)[span_4](end_span)

chmod +x /usr/local/bin/zivpn

# ==============================
# CHECK BINARY
# ==============================

if [[ ! -f /usr/local/bin/zivpn ]]; then
    echo -e "${RED}Failed downloading binary!${NC}"
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

if [[ -f "$BASE_DIR/config/zivpn_users.db" ]]; then
    cp "$BASE_DIR/config/zivpn_users.db" /etc/zivpn/users.db
else
    touch /etc/zivpn/users.db
    echo "testuser" > /etc/zivpn/users.db[span_5](start_span)[span_5](end_span)
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
-out /etc/zivpn/zivpn.crt >/dev/null 2>&1[span_6](start_span)[span_6](end_span)

# ==============================
# GENERATE CONFIG
# ==============================

echo -e "${YELLOW}[*] Generating config...${NC}"

USERS=$(awk '{print "\"" $1 "\""}' /etc/zivpn/users.db | paste -sd "," -)[span_7](start_span)[span_7](end_span)

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
EOF[span_8](start_span)[span_8](end_span)

# ==============================
# SYSTEM OPTIMIZATION
# ==============================

echo -e "${YELLOW}[*] Optimizing UDP buffer...${NC}"

sysctl -w net.core.rmem_max=16777216 >/dev/null[span_9](start_span)[span_9](end_span)
sysctl -w net.core.wmem_max=16777216 >/dev/null[span_10](start_span)[span_10](end_span)

grep -q "net.core.rmem_max" /etc/sysctl.conf || \
echo "net.core.rmem_max=16777216" >> /etc/sysctl.conf[span_11](start_span)[span_11](end_span)

grep -q "net.core.wmem_max" /etc/sysctl.conf || \
echo "net.core.wmem_max=16777216" >> /etc/sysctl.conf[span_12](start_span)[span_12](end_span)

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
EOF[span_13](start_span)[span_13](end_span)

# ==============================
# IPTABLES RULE
# ==============================

echo -e "${YELLOW}[*] Setting iptables rules...${NC}"

iptables -t nat -C PREROUTING \
-p udp --dport 6000:19999 \
-j REDIRECT --to-ports 5667 2>/dev/null || \
iptables -t nat -A PREROUTING \
-p udp --dport 6000:19999 \
-j REDIRECT --to-ports 5667[span_14](start_span)[span_14](end_span)

# ==============================
# SAVE IPTABLES
# ==============================

echo -e "${YELLOW}[*] Saving iptables rules...${NC}"

DEBIAN_FRONTEND=noninteractive \
apt-get install -y iptables-persistent >/dev/null 2>&1[span_15](start_span)[span_15](end_span)

netfilter-persistent save >/dev/null 2>&1[span_16](start_span)[span_16](end_span)

# ==============================
# ENABLE SERVICE
# ==============================

echo -e "${YELLOW}[*] Starting service...${NC}"

systemctl daemon-reload
systemctl enable zivpn >/dev/null 2>&1[span_17](start_span)[span_17](end_span)
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
echo -e " Default User   : testuser"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

