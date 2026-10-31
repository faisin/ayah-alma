#!/bin/bash
# Setup SSH WebSocket + UDPGW - by Ayah-Alma
# Corrected and aligned with AYAH ALMA repository structure

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${GREEN}▶️ Installing SSH + WebSocket + UDP Custom...${NC}"
sleep 1

# ================= INSTALL DEPENDENCY =================

echo ""
echo -e "${GREEN}[INFO] Installing dependencies...${NC}"

apt-get update -y || {
    echo -e "${RED}[ERROR] apt update gagal.${NC}"
    exit 1
}

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    openssh-server \
    curl \
    wget \
    golang-go \
    libtomcrypt1 \
    libtommath1 \
    jq \
    openssl \
    file \
    iproute2 \
    dropbear || {
    echo -e "${RED}[ERROR] Gagal memasang dependency.${NC}"
    exit 1
}

mkdir -p /usr/local/bin

# ================= INSTALL / CONFIGURE DROPBEAR =================

echo ""
echo -e "${GREEN}[INFO] Configuring Dropbear...${NC}"
echo ""

systemctl disable --now dropbear.socket 2>/dev/null || true
systemctl stop dropbear 2>/dev/null || true
systemctl stop dropbear-ws stunnel-ws dropbear-wss 2>/dev/null || true

# Remove obsolete services from previous AYAH ALMA revisions.
# stunnel-ws is a CURRENT service and must not be deleted.
for old_svc in ws-stunnel ws-dropbear ayah-ssh-ssl stunnel4 dropbear-wss; do
    systemctl disable --now "$old_svc" 2>/dev/null || true
done

rm -f \
    /etc/systemd/system/ws-stunnel.service \
    /etc/systemd/system/ws-dropbear.service \
    /etc/systemd/system/ayah-ssh-ssl.service \
    /etc/systemd/system/dropbear-wss.service

rm -f \
    /usr/local/bin/ws-stunnel \
    /usr/local/bin/ws-dropbear \
    /usr/local/bin/dropbearwss

systemctl daemon-reload

# Refuse to use ports already occupied by another daemon.
for port in 109 143 2082 2096; do
    if ss -H -lnt "sport = :$port" 2>/dev/null | grep -q .; then
        echo -e "${RED}[ERROR] TCP port $port masih dipakai layanan lain.${NC}"
        ss -lntp "sport = :$port" 2>/dev/null || true
        exit 1
    fi
done

# OpenSSH must not conflict with Dropbear ports.
if command -v sshd >/dev/null 2>&1; then
    for port in 109 143; do
        if sshd -T 2>/dev/null |
            awk '$1 == "port" {print $2}' |
            grep -qx "$port"; then

            echo -e "${RED}[ERROR] OpenSSH juga memakai port $port.${NC}"
            echo -e "${RED}Sisakan OpenSSH pada port 22.${NC}"
            exit 1
        fi
    done
fi

cat > /etc/default/dropbear <<'EOF'
NO_START=1
DROPBEAR_PORT=109
DROPBEAR_EXTRA_ARGS="-p 143 -W 65536 -b /etc/issue.net"
DROPBEAR_RECEIVE_WINDOW=65536
EOF

mkdir -p /etc/dropbear

if [ ! -f /etc/dropbear/dropbear_rsa_host_key ]; then
    dropbearkey -t rsa \
        -f /etc/dropbear/dropbear_rsa_host_key >/dev/null 2>&1 || {
        echo -e "${RED}[ERROR] Gagal membuat RSA host key.${NC}"
        exit 1
    }
fi

if [ ! -f /etc/dropbear/dropbear_ecdsa_host_key ]; then
    dropbearkey -t ecdsa \
        -f /etc/dropbear/dropbear_ecdsa_host_key >/dev/null 2>&1 || {
        echo -e "${RED}[ERROR] Gagal membuat ECDSA host key.${NC}"
        exit 1
    }
fi

# ================= INSTALL ISSUE.NET =================

if [ -f "$SCRIPT_DIR/config/issue.net" ]; then
    cp "$SCRIPT_DIR/config/issue.net" /etc/issue.net
else
    echo -e "${RED}[ERROR] config/issue.net tidak ditemukan.${NC}"
    exit 1
fi

chmod 644 /etc/issue.net

# ================= DROPBEAR PUBLIC PORTS =================
# Dropbear directly owns TCP 109 and 143.
# HAProxy does not bind these ports.

cat > /etc/systemd/system/dropbear.service <<'EOF'
[Unit]
Description=AYAH ALMA Dropbear SSH (ports 109 and 143)
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/dropbear -E -F -p 109 -p 143 -r /etc/dropbear/dropbear_rsa_host_key -r /etc/dropbear/dropbear_ecdsa_host_key -W 65536 -b /etc/issue.net
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

# ================= BUILD GO WEBSOCKET SERVICES =================

echo ""
echo -e "${GREEN}[INFO] Building Go WebSocket Services...${NC}"
echo ""

if ! command -v go >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] Go compiler tidak tersedia.${NC}"
    exit 1
fi

GO_DIR="$SCRIPT_DIR/internal/go"

# Validate source directories.
for source in dropbear-ws stunnel-ws; do
    if [ ! -f "$GO_DIR/$source/main.go" ]; then
        echo -e "${RED}[ERROR] Source $source/main.go tidak ditemukan.${NC}"
        exit 1
    fi
done

if [ ! -f "$GO_DIR/go.mod" ]; then
    echo -e "${RED}[ERROR] internal/go/go.mod tidak ditemukan.${NC}"
    exit 1
fi

# Build Dropbear WebSocket.
echo -e "${GREEN}[INFO] Building dropbear-ws...${NC}"

(
    cd "$GO_DIR" &&
    go build -ldflags="-s -w" \
        -o /usr/local/bin/dropbearws \
        ./dropbear-ws
) || {
    echo -e "${RED}[ERROR] Build dropbear-ws gagal.${NC}"
    exit 1
}

# Build Stunnel WebSocket.
echo -e "${GREEN}[INFO] Building stunnel-ws...${NC}"

(
    cd "$GO_DIR" &&
    go build -ldflags="-s -w" \
        -o /usr/local/bin/stunnelws \
        ./stunnel-ws
) || {
    echo -e "${RED}[ERROR] Build stunnel-ws gagal.${NC}"
    exit 1
}

chmod 755 \
    /usr/local/bin/dropbearws \
    /usr/local/bin/stunnelws

[ -x /usr/local/bin/dropbearws ] || {
    echo -e "${RED}[ERROR] Binary dropbearws tidak berhasil dibuat.${NC}"
    exit 1
}

[ -x /usr/local/bin/stunnelws ] || {
    echo -e "${RED}[ERROR] Binary stunnelws tidak berhasil dibuat.${NC}"
    exit 1
}

# ================= INSTALL GO SYSTEMD SERVICES =================

if [ ! -f "$GO_DIR/dropbear-ws.service" ]; then
    echo -e "${RED}[ERROR] dropbear-ws.service tidak ditemukan.${NC}"
    exit 1
fi

if [ ! -f "$GO_DIR/stunnel-ws.service" ]; then
    echo -e "${RED}[ERROR] stunnel-ws.service tidak ditemukan.${NC}"
    exit 1
fi

cp "$GO_DIR/dropbear-ws.service" \
    /etc/systemd/system/dropbear-ws.service

cp "$GO_DIR/stunnel-ws.service" \
    /etc/systemd/system/stunnel-ws.service

# ================= INSTALL BADVPN UDPGW =================

echo ""
echo -e "${GREEN}[INFO] Installing BadVPN UDPGW...${NC}"
echo ""

ARCH="$(dpkg --print-architecture 2>/dev/null || true)"

BADVPN_BIN="$SCRIPT_DIR/bin/$ARCH/badvpn-udpgw"

if [ ! -f "$BADVPN_BIN" ]; then
    echo -e "${RED}[ERROR] Binary badvpn-udpgw tidak ditemukan: $BADVPN_BIN${NC}"
    exit 1
fi

if ! file "$BADVPN_BIN" | grep -q 'ELF'; then
    echo -e "${RED}[ERROR] badvpn-udpgw bukan ELF valid.${NC}"
    exit 1
fi

install -m 755 "$BADVPN_BIN" /usr/local/bin/badvpn-udpgw

if [ ! -f "$SCRIPT_DIR/sshws/udpgw.service" ]; then
    echo -e "${RED}[ERROR] udpgw.service tidak ditemukan.${NC}"
    exit 1
fi

cp "$SCRIPT_DIR/sshws/udpgw.service" \
    /etc/systemd/system/udpgw.service

# ================= INSTALL UDP CUSTOM =================

echo ""
echo -e "${GREEN}[INFO] Installing UDP Custom...${NC}"
echo ""

UDP_BIN="$SCRIPT_DIR/bin/$ARCH/udp-custom"

if [ ! -f "$UDP_BIN" ]; then
    echo -e "${RED}[ERROR] Binary udp-custom tidak ditemukan: $UDP_BIN${NC}"
    exit 1
fi

if ! file "$UDP_BIN" | grep -q 'ELF'; then
    echo -e "${RED}[ERROR] udp-custom bukan ELF valid.${NC}"
    exit 1
fi

install -m 755 "$UDP_BIN" /usr/local/bin/udp-custom

mkdir -p /etc/udp-custom

if [ ! -f "$SCRIPT_DIR/config/udp-custom.json" ]; then
    echo -e "${RED}[ERROR] config/udp-custom.json tidak ditemukan.${NC}"
    exit 1
fi

# Preserve a valid existing configuration.
if [ -s /etc/udp-custom/config.json ] &&
    jq -e '.auth.config | type == "array" and length > 0' \
        /etc/udp-custom/config.json >/dev/null 2>&1; then

    echo -e "${GREEN}[INFO] Konfigurasi/password UDP Custom yang sudah ada dipertahankan.${NC}"

else
    initial_udp_password="$(openssl rand -hex 12)"

    jq --arg password "$initial_udp_password" \
        '.auth.config = [$password]' \
        "$SCRIPT_DIR/config/udp-custom.json" \
        > /etc/udp-custom/config.json || {
        echo -e "${RED}[ERROR] Gagal membuat konfigurasi UDP Custom.${NC}"
        exit 1
    }

    chmod 600 /etc/udp-custom/config.json

    printf '%s\n' "$initial_udp_password" \
        > /root/udp-custom-initial-password.txt

    chmod 600 /root/udp-custom-initial-password.txt

    if [[ -w /dev/tty ]]; then
        printf '[PENTING] Password UDP Custom awal: %s\nSimpan password ini. Salinan root-only: /root/udp-custom-initial-password.txt\n' \
            "$initial_udp_password" > /dev/tty
    else
        echo -e "${YELLOW}[PENTING] Password UDP Custom disimpan di /root/udp-custom-initial-password.txt (izin 600).${NC}"
    fi
fi

if [ ! -f "$SCRIPT_DIR/sshws/udp-custom.service" ]; then
    echo -e "${RED}[ERROR] udp-custom.service tidak ditemukan.${NC}"
    exit 1
fi

cp "$SCRIPT_DIR/sshws/udp-custom.service" \
    /etc/systemd/system/udp-custom.service

# ================= PERMISSION & SYSTEMD RELOAD =================

chmod 644 \
    /etc/systemd/system/dropbear.service \
    /etc/systemd/system/dropbear-ws.service \
    /etc/systemd/system/stunnel-ws.service \
    /etc/systemd/system/udpgw.service \
    /etc/systemd/system/udp-custom.service

systemctl daemon-reload

# ================= ENABLE & START SERVICES =================

echo ""
echo -e "${GREEN}[INFO] Enabling SSH services...${NC}"

for svc in ssh dropbear dropbear-ws stunnel-ws udpgw udp-custom; do
    if systemctl list-unit-files --type=service --no-legend |
        awk '{print $1}' |
        grep -qx "${svc}.service"; then

        systemctl enable "$svc" >/dev/null 2>&1 || {
            echo -e "${RED}[ERROR] Gagal enable $svc.${NC}"
            exit 1
        }

        systemctl restart "$svc" || {
            echo -e "${RED}[ERROR] Gagal menjalankan $svc.${NC}"
            exit 1
        }
    else
        echo -e "${RED}[ERROR] Unit ${svc}.service tidak ditemukan.${NC}"
        exit 1
    fi
done

# ================= INSTALL LOG =================

touch /root/log-install.txt

cat >> /root/log-install.txt <<'EOF'

━━━━━━━━━━━━━━━━━━━━━━
SSH PANEL (AYAH-ALMA)
━━━━━━━━━━━━━━━━━━━━━━

OpenSSH             : 22
Dropbear            : 109,143 (langsung)
SSH WebSocket       : 80 /ssh-ws -> 127.0.0.1:2082 -> Dropbear 109
SSH WSS             : 443 /ssh-wss -> 127.0.0.1:2096 -> Dropbear 143
HAProxy             : satu-satunya listener publik 80/443
BadVPN UDPGW        : 7300

━━━━━━━━━━━━━━━━━━━━━━

EOF

echo ""
echo -e "${GREEN}[ OK ] SSH + Dropbear + WebSocket + UDPGW Installation Completed (Ayah-Alma)${NC}"
echo ""
