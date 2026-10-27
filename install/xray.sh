#!/bin/bash
# Setup Xray Core + HAProxy Reverse Proxy - by Ayah-Alma
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

if ! command -v haproxy >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] HAProxy belum terpasang!${NC}"
    echo -e "${RED}Jalankan install/haproxy.sh terlebih dahulu.${NC}"
    exit 1
fi

# ================= INSTALL DEPENDENCY =================

apt update -y || exit 1

apt install -y \
    curl wget cron jq unzip \
    gnupg coreutils lsof qrencode \
    ca-certificates openssl file haproxy || exit 1

mkdir -p /etc/xray /var/log/xray /usr/local/bin /etc/haproxy/certs

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

# ================= ACME CERTIFICATE =================
# Sertifikat HTTP-01 Standalone untuk domain layanan yang dipilih.
# Metode ini tidak menerbitkan sertifikat wildcard.
CERT_DOMAIN="$domain"

printf '\n\\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\\033[0m\n'
printf '\\033[1;36m   PENGATURAN SERTIFIKAT LET\\x27S ENCRYPT\\033[0m\n'
printf '\\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\\033[0m\n'
echo "Domain layanan    : $domain"
echo "Domain sertifikat : $CERT_DOMAIN"
echo "Metode            : HTTP-01 Standalone (port 80)"
echo "Catatan           : DNS domain harus mengarah ke VPS dan TCP port 80 harus terbuka."

echo -e "${GREEN}🔐 Memastikan acme.sh tersedia...${NC}"
if [[ ! -s "$HOME/.acme.sh/acme.sh" ]]; then
    curl -fsSL --retry 3 --connect-timeout 15 https://get.acme.sh | sh -s email="admin@$CERT_DOMAIN" || {
        echo -e "${RED}[ERROR] Gagal memasang acme.sh.${NC}"
        exit 1
    }
fi
ACME="$HOME/.acme.sh/acme.sh"
[[ -s "$ACME" ]] || { echo -e "${RED}[ERROR] Binary acme.sh tidak ditemukan.${NC}"; exit 1; }
chmod +x "$ACME"
"$ACME" --set-default-ca --server letsencrypt || {
    echo -e "${RED}[ERROR] Gagal memilih Let's Encrypt.${NC}"
    exit 1
}
if ! "$ACME" --register-account -m "admin@$CERT_DOMAIN"; then
    echo -e "${YELLOW}[PERINGATAN] Akun ACME mungkin sudah terdaftar; melanjutkan.${NC}"
fi

echo -e "${YELLOW}[INFO] Menghentikan HAProxy sementara untuk validasi HTTP-01 port 80...${NC}"
HAPROXY_WAS_ACTIVE="$(systemctl is-active haproxy 2>/dev/null || true)"
HAPROXY_TEMP_STOPPED=true
restore_haproxy() {
    [[ "${HAPROXY_TEMP_STOPPED:-false}" == "true" ]] || return 0
    if [[ "${HAPROXY_WAS_ACTIVE:-inactive}" == "active" ]]; then
        systemctl start haproxy >/dev/null 2>&1 || echo "[WARNING] HAProxy gagal dipulihkan otomatis; periksa systemctl status haproxy." >&2
    else
        systemctl stop haproxy >/dev/null 2>&1 || true
    fi
}
trap restore_haproxy EXIT

if lsof -nP -iTCP:80 -sTCP:LISTEN 2>/dev/null | grep -q LISTEN; then
    echo -e "${RED}[ERROR] Port 80 masih digunakan proses lain setelah HAProxy dihentikan.${NC}"
    exit 1
fi

"$ACME" --issue --standalone -d "$CERT_DOMAIN" --keylength ec-256 \
    --pre-hook "systemctl stop haproxy" \
    --post-hook 'if grep -q "^frontend ayah_http_80" /etc/haproxy/haproxy.cfg 2>/dev/null; then systemctl start haproxy; fi' || {
    echo -e "${RED}[ERROR] Gagal menerbitkan sertifikat HTTP-01 Standalone. Pastikan DNS domain mengarah ke VPS dan TCP port 80 terbuka.${NC}"
    exit 1
}

systemctl stop haproxy >/dev/null 2>&1 || true
# Trap tetap aktif sampai konfigurasi final berhasil dan HAProxy kembali sehat.

# ================= INSTALL CERTIFICATE =================

mkdir -p /etc/xray

"$ACME" \
    --install-cert \
    -d "$CERT_DOMAIN" \
    --ecc \
    --key-file /etc/xray/private.key \
    --fullchain-file /etc/xray/cert.crt \
    --reloadcmd 'cat /etc/xray/cert.crt /etc/xray/private.key > /etc/haproxy/certs/ayah-alma.pem && chmod 600 /etc/haproxy/certs/ayah-alma.pem && if grep -q "^frontend ayah_http_80" /etc/haproxy/haproxy.cfg 2>/dev/null; then haproxy -c -f /etc/haproxy/haproxy.cfg && systemctl reload haproxy || systemctl restart haproxy; fi; if systemctl is-active --quiet xray; then systemctl restart xray; fi; if systemctl is-active --quiet ayah-ssh-ssl; then systemctl restart ayah-ssh-ssl; fi' || {
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

# ================= FINAL HAPROXY CONFIG =================
# HAProxy owns public ports 80 and 443; Nginx is not used for tunneling.
cat /etc/xray/cert.crt /etc/xray/private.key > /etc/haproxy/certs/ayah-alma.pem
chmod 600 /etc/haproxy/certs/ayah-alma.pem

HAPROXY_TEMPLATE="$SCRIPT_DIR/config/haproxy.cfg"
[[ -s "$HAPROXY_TEMPLATE" ]] || { echo -e "${RED}[ERROR] Template config/haproxy.cfg tidak ditemukan.${NC}"; exit 1; }
HAPROXY_RENDERED="$(mktemp /tmp/ayah-alma-haproxy.XXXXXX)"
cp "$HAPROXY_TEMPLATE" "$HAPROXY_RENDERED"
IPV6_DISABLED="$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null || echo 1)"
if [[ "$IPV6_DISABLED" != "0" ]]; then
    sed -i '/^[[:space:]]*bind :::[0-9]/d' "$HAPROXY_RENDERED"
    echo -e "${YELLOW}[WARNING] IPv6 dinonaktifkan; listener IPv6 HAProxy dilewati.${NC}"
fi
install -m 644 "$HAPROXY_RENDERED" /etc/haproxy/haproxy.cfg
rm -f "$HAPROXY_RENDERED"

haproxy -c -f /etc/haproxy/haproxy.cfg || {
    echo -e "${RED}[ERROR] Konfigurasi HAProxy tidak valid.${NC}"
    exit 1
}

# ================= XRAY CONFIG =================

# Simpan konfigurasi lama sebelum menulis template baru agar akun/pengaturan
# sebelumnya masih dapat dipulihkan bila installer dijalankan ulang.
if [[ -s /etc/xray/config.json ]]; then
    backup="/etc/xray/config.json.bak.$(date +%Y%m%d%H%M%S)"
    cp -a /etc/xray/config.json "$backup"
    echo "[INFO] Konfigurasi Xray sebelumnya dicadangkan ke $backup"
fi
cp "$SCRIPT_DIR/config/xray.json" /etc/xray/config.json
chmod 644 /etc/xray/config.json

# Pastikan inbound HTTPUpgrade tersedia tanpa menghapus inbound/klien yang sudah ada.
# WS tetap dipertahankan; HTTPUpgrade memakai port loopback dan path terpisah.
for tag in vmess-httpupgrade vless-httpupgrade trojan-httpupgrade; do
    if ! jq -e --arg tag "$tag" '.inbounds[]? | select(.tag == $tag)' /etc/xray/config.json >/dev/null; then
        case "$tag" in
            vmess-httpupgrade) proto=vmess; port=14019; path=/upvmess ;;
            vless-httpupgrade) proto=vless; port=14018; path=/upvless ;;
            trojan-httpupgrade) proto=trojan; port=14020; path=/uptrojan ;;
        esac
        tmp_config=$(mktemp /etc/xray/config.json.XXXXXX)
        jq --arg tag "$tag" --arg proto "$proto" --argjson port "$port" --arg path "$path" \
          '.inbounds += [{"listen":"127.0.0.1","port":$port,"protocol":$proto,"settings":(if $proto == "vless" then {"clients":[],"decryption":"none"} else {"clients":[]} end),"streamSettings":{"network":"httpupgrade","security":"none","httpupgradeSettings":{"path":$path}},"tag":$tag}]' \
          /etc/xray/config.json > "$tmp_config" || { rm -f "$tmp_config"; echo -e "${RED}[ERROR] Gagal menambahkan inbound $tag.${NC}"; exit 1; }
        install -m 644 "$tmp_config" /etc/xray/config.json
        rm -f "$tmp_config"
        echo -e "${GREEN}[INFO] Inbound HTTPUpgrade ditambahkan: $tag 127.0.0.1:$port path $path${NC}"
    else
        echo -e "${GREEN}[INFO] Inbound HTTPUpgrade sudah ada: $tag${NC}"
    fi
done

# Rute HTTPUpgrade /upvmess, /upvless, dan /uptrojan sudah tersedia di config/haproxy.cfg.

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

echo -e "${GREEN}🧪 Testing HAProxy Config...${NC}"

haproxy -c -f /etc/haproxy/haproxy.cfg || {
    echo -e "${RED}[ERROR] Invalid HAProxy configuration!${NC}"
    exit 1
}

echo -e "${GREEN}🧪 Testing XRAY Config...${NC}"

/usr/local/bin/xray -test -config /etc/xray/config.json || {
    echo -e "${RED}[ERROR] Invalid XRAY configuration!${NC}"
    exit 1
}

# ================= START SERVICE =================

systemctl daemon-reload || exit 1
systemctl enable xray haproxy || exit 1

systemctl restart xray
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

# Kedua layanan sudah sehat; hentikan trap pemulihan sementara.
HAPROXY_TEMP_STOPPED=false
trap - EXIT

# ================= INSTALL LOG =================
touch /root/log-install.txt
cat >> /root/log-install.txt <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
XRAY PANEL (AYAH-ALMA)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Domain layanan       : ${domain}
Sertifikat           : ${CERT_DOMAIN}
Sertifikat metode    : Let's Encrypt HTTP-01 Standalone

WebSocket:
VMess WS TLS         : 443 /vmess -> 127.0.0.1:23456
VMess WS non-TLS     : 80  /vmess -> 127.0.0.1:23457
VLESS WS TLS         : 443 /vless -> 127.0.0.1:14016
VLESS WS non-TLS     : 80  /vless -> 127.0.0.1:14017
Trojan WS TLS        : 443 /trojan-ws -> 127.0.0.1:25432
Trojan WS non-TLS    : 80  /trojan-ws -> 127.0.0.1:25432

HTTPUpgrade (HAProxy port 80 dan 443):
VMess HTTPUpgrade    : /upvmess  -> 127.0.0.1:14019
VLESS HTTPUpgrade    : /upvless  -> 127.0.0.1:14018
Trojan HTTPUpgrade   : /uptrojan -> 127.0.0.1:14020

Konfigurasi Xray     : /etc/xray/config.json
Konfigurasi HAProxy  : /etc/haproxy/haproxy.cfg
Sertifikat           : /etc/xray/cert.crt
Private key          : /etc/xray/private.key
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
echo -e "HAProxy Config : /etc/haproxy/haproxy.cfg"
echo -e "TLS Certificate: ${CERT_DOMAIN}"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
