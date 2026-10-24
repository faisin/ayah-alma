#!/bin/bash
# Setup Xray Core + Nginx Reverse Proxy - by Ayah-Alma
# Converted for Ayah-Alma Project

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
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

apt update -y || exit 1

apt install -y \
    curl wget cron jq unzip \
    gnupg coreutils lsof qrencode \
    ca-certificates openssl file libnginx-mod-stream || exit 1

mkdir -p /etc/xray /var/log/xray /usr/local/bin /etc/nginx/streams-enabled

# ================= INSTALL VENDORED XRAY =================

echo -e "${GREEN}⬇️ Installing vendored Xray Core...${NC}"

ARCH="$(dpkg --print-architecture 2>/dev/null || true)"

case "$ARCH" in
    amd64|arm64) ;;
    *)
        echo -e "${RED}[ERROR] Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

XRAY_BIN="$SCRIPT_DIR/bin/$ARCH/xray"

if [[ ! -f "$XRAY_BIN" ]]; then
    echo -e "${RED}[ERROR] Vendored Xray binary not found: $XRAY_BIN${NC}"
    exit 1
fi

file "$XRAY_BIN" | grep -q 'ELF' || {
    echo -e "${RED}[ERROR] Xray binary is not a valid ELF executable.${NC}"
    exit 1
}

install -m 755 "$XRAY_BIN" /usr/local/bin/xray

/usr/local/bin/xray version >/dev/null 2>&1 || {
    echo -e "${RED}[ERROR] Xray binary failed validation.${NC}"
    exit 1
}

# ================= DOMAIN LAYANAN =================

if [[ -f /root/domain ]]; then
    domain="$(tr -d '\r\n' < /root/domain)"
elif [[ -f /etc/xray/domain ]]; then
    domain="$(tr -d '\r\n' < /etc/xray/domain)"
else
    echo -e "${RED}[ERROR] File domain not found!${NC}"
    exit 1
fi

if [[ -z "$domain" ]]; then
    echo -e "${RED}[ERROR] Domain layanan kosong!${NC}"
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

systemctl enable cron || exit 1
systemctl restart cron || exit 1

# ================= ACME HTTP-01 STANDALONE =================
# Standalone memakai port 80, jadi Nginx dihentikan sementara saat penerbitan.
# Sertifikat hanya diterbitkan untuk domain layanan; metode HTTP-01 tidak mendukung wildcard.

CERT_DOMAIN="$domain"

printf '\n\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n'
printf '\033[1;36m   PENGATURAN SERTIFIKAT LET\x27S ENCRYPT\033[0m\n'
printf '\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n'

echo "Domain layanan    : $domain"
echo "Domain sertifikat : $CERT_DOMAIN"
echo "Metode            : HTTP-01 Standalone"
echo "Port validasi     : 80 (Nginx dihentikan sementara)"
echo

# Instal acme.sh hanya jika belum tersedia.
if [[ ! -s "$HOME/.acme.sh/acme.sh" ]]; then
    echo -e "${GREEN}🔐 Menginstall acme.sh...${NC}"

    curl -fsSL --retry 3 --connect-timeout 15 https://get.acme.sh |
        sh -s email="admin@$CERT_DOMAIN" || {
            echo -e "${RED}[ERROR] Gagal memasang acme.sh.${NC}"
            exit 1
        }
fi

ACME="$HOME/.acme.sh/acme.sh"

if [[ ! -s "$ACME" ]]; then
    echo -e "${RED}[ERROR] Binary acme.sh tidak ditemukan.${NC}"
    exit 1
fi

chmod +x "$ACME"

"$ACME" --set-default-ca --server letsencrypt || {
    echo -e "${RED}[ERROR] Gagal memilih Let's Encrypt.${NC}"
    exit 1
}

if ! "$ACME" --register-account -m "admin@$CERT_DOMAIN"; then
    echo -e "${YELLOW}[PERINGATAN] Registrasi akun gagal atau akun sudah terdaftar. Melanjutkan ke penerbitan sertifikat.${NC}"
fi

# Pastikan Nginx hidup kembali, termasuk jika penerbitan sertifikat gagal.
restore_nginx() {
    systemctl start nginx || true
}
trap restore_nginx EXIT

echo -e "${YELLOW}[INFO] Menghentikan Nginx sementara agar port 80 tersedia...${NC}"
systemctl stop nginx || {
    echo -e "${RED}[ERROR] Gagal menghentikan Nginx.${NC}"
    exit 1
}

sleep 1
if lsof -nP -iTCP:80 -sTCP:LISTEN 2>/dev/null | grep -q LISTEN; then
    echo -e "${RED}[ERROR] Port 80 masih digunakan proses lain; sertifikat tidak diterbitkan.${NC}"
    exit 1
fi

echo -e "${GREEN}Menerbitkan sertifikat Let's Encrypt melalui HTTP-01 Standalone...${NC}"
"$ACME" \
    --issue --standalone \
    -d "$CERT_DOMAIN" \
    --keylength ec-256 \
    --pre-hook "systemctl stop nginx" \
    --post-hook "systemctl start nginx" || {
        echo -e "${RED}[ERROR] Gagal menerbitkan sertifikat HTTP-01.${NC}"
        echo -e "${RED}Pastikan DNS domain mengarah ke IP VPS dan TCP port 80 dapat diakses dari internet.${NC}"
        exit 1
    }

# Nginx disambungkan kembali segera setelah proses penerbitan selesai.
systemctl start nginx || {
    echo -e "${RED}[ERROR] Sertifikat terbit, tetapi Nginx gagal dinyalakan kembali.${NC}"
    exit 1
}
trap - EXIT

# ================= INSTALL CERTIFICATE =================

mkdir -p /etc/xray

"$ACME" \
    --install-cert \
    -d "$CERT_DOMAIN" \
    --ecc \
    --key-file /etc/xray/private.key \
    --fullchain-file /etc/xray/cert.crt \
    --reloadcmd 'if systemctl is-active --quiet nginx; then systemctl reload nginx; fi; if systemctl is-active --quiet xray; then systemctl restart xray; fi; if systemctl is-active --quiet ayah-ssh-ssl; then systemctl restart ayah-ssh-ssl; fi' || {
        echo -e "${RED}[ERROR] Gagal memasang sertifikat.${NC}"
        exit 1
    }

# ================= PERMISSION =================

if [[ ! -s /etc/xray/private.key || ! -s /etc/xray/cert.crt ]]; then
    echo -e "${RED}[ERROR] Sertifikat atau private key tidak ditemukan.${NC}"
    exit 1
fi

openssl x509 \
    -in /etc/xray/cert.crt \
    -noout -checkend 0 >/dev/null 2>&1 || {
        echo -e "${RED}[ERROR] Sertifikat tidak valid atau kedaluwarsa.${NC}"
        exit 1
    }

chmod 600 /etc/xray/private.key
chmod 644 /etc/xray/cert.crt

# ================= FINAL NGINX TLS CONFIG =================
# Nginx digunakan langsung.
# Tidak menonaktifkan HAProxy atau layanan lain.

rm -f /etc/nginx/conf.d/acme-bootstrap.conf

# Ensure stream context exists for raw TCP/TLS passthrough listeners.
if ! grep -Eq '^[[:space:]]*stream[[:space:]]*\{' /etc/nginx/nginx.conf; then
    if grep -Eq '^[[:space:]]*http[[:space:]]*\{' /etc/nginx/nginx.conf; then
        sed -i '/^[[:space:]]*http[[:space:]]*{/i stream {\n    include /etc/nginx/streams-enabled/*.conf;\n}\n' /etc/nginx/nginx.conf
    else
        echo -e "${RED}[ERROR] Tidak menemukan blok http {} di /etc/nginx/nginx.conf.${NC}"
        exit 1
    fi
fi

cp "$SCRIPT_DIR/config/xray-stream.conf" /etc/nginx/streams-enabled/xray-stream.conf
chmod 644 /etc/nginx/streams-enabled/xray-stream.conf
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
    echo -e "${RED}[ERROR] NGINX failed to start!${NC}"
    journalctl -u nginx -n 30 --no-pager
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

/usr/local/bin/xray -test -config /etc/xray/config.json || {
    echo -e "${RED}[ERROR] Invalid XRAY configuration!${NC}"
    exit 1
}

# ================= START SERVICE =================

systemctl daemon-reload || exit 1
systemctl enable xray nginx || exit 1

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

echo -e "Domain         : ${domain}
Raw TLS SNI    : ${vmess_domain}, ${vless_domain}, ${trojan_domain}"

echo -e "XRAY Config    : /etc/xray/config.json"
echo -e "NGINX Config   : /etc/nginx/conf.d/xray.conf"
echo -e "TLS Certificate: ${CERT_DOMAIN}"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
