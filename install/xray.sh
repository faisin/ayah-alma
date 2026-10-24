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
curl wget cron jq unzip \
gnupg coreutils lsof qrencode \
ca-certificates

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
    curl -fsSL --retry 3 --connect-timeout 15 https://get.acme.sh | sh -s email="admin@$domain" || {
        echo -e "${RED}[ERROR] Gagal mengunduh/memasang acme.sh.${NC}"
        exit 1
    }
fi

[[ -s "$HOME/.acme.sh/acme.sh" ]] || { echo -e "${RED}[ERROR] Binary acme.sh tidak ditemukan.${NC}"; exit 1; }
chmod +x "$HOME/.acme.sh/acme.sh"

"$HOME/.acme.sh/acme.sh" --set-default-ca --server letsencrypt
if ! "$HOME/.acme.sh/acme.sh" --register-account -m "admin@$domain"; then
    echo -e "${RED}[WARNING] Registrasi akun ACME gagal; lanjut hanya jika akun sudah terdaftar dan proses issue berhasil.${NC}"
fi

# ================= ACME DNS-01 CLOUDFLARE =================

printf '\n\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n'
printf '\033[1;36m   PENGATURAN SERTIFIKAT WILDCARD\033[0m\n'
printf '\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n'
echo "Domain utama : $domain"
echo "Sertifikat   : $domain dan *.$domain"
echo "Metode       : DNS-01 Cloudflare"
echo
echo "Token memerlukan izin Zone:DNS:Edit dan Zone:Zone:Read"
echo "untuk zona domain ini. Token tidak boleh diunggah ke GitHub."
echo

if [[ -r /dev/tty ]]; then
    read -rsp "Masukkan Cloudflare API Token: " CF_Token </dev/tty
    printf '\n'
else
    read -rsp "Masukkan Cloudflare API Token: " CF_Token
    printf '\n'
fi
[[ -n "${CF_Token:-}" ]] || { echo -e "${RED}[ERROR] Token Cloudflare tidak boleh kosong.${NC}"; exit 1; }

# Simpan kredensial dengan izin ketat; jangan tampilkan token ke log.
mkdir -p /root/.acme.sh
chmod 700 /root/.acme.sh
umask 077
export CF_Token

# Pasang dependensi DNS dan pastikan acme.sh tersedia.
if [[ ! -s "$HOME/.acme.sh/acme.sh" ]]; then
    echo -e "${GREEN}Menginstall acme.sh...${NC}"
    curl -fsSL --retry 3 --connect-timeout 15 https://get.acme.sh | sh -s email="admin@$domain" || {
        echo -e "${RED}[ERROR] Gagal mengunduh/memasang acme.sh.${NC}"
        exit 1
    }
fi
[[ -s "$HOME/.acme.sh/acme.sh" ]] || { echo -e "${RED}[ERROR] Binary acme.sh tidak ditemukan.${NC}"; exit 1; }
chmod +x "$HOME/.acme.sh/acme.sh"
"$HOME/.acme.sh/acme.sh" --set-default-ca --server letsencrypt
if ! "$HOME/.acme.sh/acme.sh" --register-account -m "admin@$domain"; then
    echo -e "${YELLOW}[PERINGATAN] Registrasi akun ACME gagal; akan dilanjutkan jika akun sudah terdaftar.${NC}"
fi

# DNS-01 tidak membutuhkan HTTP challenge maupun pengambilalihan port 80/443.
echo -e "${GREEN}Menerbitkan sertifikat wildcard melalui Cloudflare DNS-01...${NC}"
"$HOME/.acme.sh/acme.sh" \
    --issue --dns dns_cf \
    -d "$domain" \
    -d "*.$domain" \
    --keylength ec-256 || {
        unset CF_Token
        echo -e "${RED}[ERROR] Gagal menerbitkan sertifikat DNS-01. Periksa token dan DNS Cloudflare.${NC}"
        exit 1
    }
unset CF_Token

# Pasang sertifikat ke lokasi yang dipakai konfigurasi Xray.
mkdir -p /etc/xray
"$HOME/.acme.sh/acme.sh" \
    --install-cert \
    -d "$domain" \
    --ecc \
    --key-file /etc/xray/private.key \
    --fullchain-file /etc/xray/cert.crt \
    --reloadcmd 'systemctl reload nginx; if systemctl is-active --quiet xray; then systemctl restart xray; fi' || {
        echo -e "${RED}[ERROR] Gagal memasang sertifikat.${NC}"
        exit 1
    }

# ================= PERMISSION =================

[[ -s /etc/xray/private.key && -s /etc/xray/cert.crt ]] || {
    echo -e "${RED}[ERROR] Sertifikat ACME atau private key tidak terpasang dengan benar.${NC}"
    exit 1
}
openssl x509 -in /etc/xray/cert.crt -noout -checkend 0 >/dev/null 2>&1 || {
    echo -e "${RED}[ERROR] Sertifikat ACME tidak valid atau sudah kedaluwarsa.${NC}"
    exit 1
}
chmod 600 /etc/xray/private.key
chmod 644 /etc/xray/cert.crt

# ================= FINAL NGINX TLS CONFIG =================

# Nginx will own public ports 80 and 443; release 443 before applying TLS config.
systemctl disable --now haproxy 2>/dev/null || true


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

systemctl enable xray nginx
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

echo -e "Domain        : ${domain}
Raw TLS SNI   : ${vmess_domain}, ${vless_domain}, ${trojan_domain}"
echo -e "XRAY Config   : /etc/xray/config.json"
echo -e "NGINX Config  : /etc/nginx/conf.d/xray.conf"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
