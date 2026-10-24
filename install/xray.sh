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

# ================= ACME CERTIFICATE =================
# Gunakan HTTP-01 Webroot dan
# tidak menerbitkan wildcard; sertifikat hanya untuk domain layanan.
CERT_DOMAIN="$domain"
ACME_MODE="http01_webroot"

printf '\n\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n'
printf '\033[1;36m   PENGATURAN SERTIFIKAT LET\x27S ENCRYPT\033[0m\n'
printf '\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n'
echo "Domain layanan    : $domain"
echo "Domain sertifikat : $CERT_DOMAIN"
echo "Metode            : HTTP-01 Webroot (port 80)"
echo "Direktori challenge: /var/www/html/.well-known/acme-challenge"

mkdir -p /var/www/html/.well-known/acme-challenge
chmod 755 /var/www/html /var/www/html/.well-known /var/www/html/.well-known/acme-challenge

echo -e "${GREEN}🔐 Memastikan acme.sh tersedia...${NC}"
if [[ ! -s "$HOME/.acme.sh/acme.sh" ]]; then
    curl -fsSL --retry 3 --connect-timeout 15 https://get.acme.sh | sh -s email="admin@$CERT_DOMAIN" || {
        echo -e "${RED}[ERROR] Gagal memasang acme.sh.${NC}"; exit 1;
    }
fi
ACME="$HOME/.acme.sh/acme.sh"
[[ -s "$ACME" ]] || { echo -e "${RED}[ERROR] Binary acme.sh tidak ditemukan.${NC}"; exit 1; }
chmod +x "$ACME"
"$ACME" --set-default-ca --server letsencrypt || { echo -e "${RED}[ERROR] Gagal memilih Let's Encrypt.${NC}"; exit 1; }
if ! "$ACME" --register-account -m "admin@$CERT_DOMAIN"; then
    echo -e "${YELLOW}[PERINGATAN] Akun ACME mungkin sudah terdaftar; melanjutkan.${NC}"
fi

echo -e "${GREEN}Menerbitkan sertifikat HTTP-01 melalui Webroot...${NC}"
"$ACME" --issue --webroot /var/www/html -d "$CERT_DOMAIN" --keylength ec-256 || {
    echo -e "${RED}[ERROR] Gagal menerbitkan sertifikat HTTP-01. Pastikan DNS mengarah ke VPS, port 80 terbuka, dan Nginx melayani /.well-known/acme-challenge/.${NC}"
    exit 1
}

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

# Pastikan rute HTTPUpgrade tersedia pada server HTTP port 80 tanpa mengubah rute WS.
python3 - /etc/nginx/conf.d/xray.conf <<'PYROUTES'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
blocks = {
    "/upvmess": '    # HTTPUpgrade VMess\n    location /upvmess { proxy_redirect off; proxy_pass http://127.0.0.1:14019; proxy_http_version 1.1; proxy_set_header Host $host; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header X-Real-IP $remote_addr; proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; proxy_read_timeout 3600; proxy_send_timeout 3600; }\n',
    "/upvless": '    # HTTPUpgrade VLESS\n    location /upvless { proxy_redirect off; proxy_pass http://127.0.0.1:14018; proxy_http_version 1.1; proxy_set_header Host $host; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header X-Real-IP $remote_addr; proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; proxy_read_timeout 3600; proxy_send_timeout 3600; }\n',
    "/uptrojan": '    # HTTPUpgrade Trojan\n    location /uptrojan { proxy_redirect off; proxy_pass http://127.0.0.1:14020; proxy_http_version 1.1; proxy_set_header Host $host; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header X-Real-IP $remote_addr; proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; proxy_read_timeout 3600; proxy_send_timeout 3600; }\n',
}
# Find every server {} block (HTTP :80 and HTTPS :443), and add missing routes to each.
pos = 0
out = []
while True:
    start = s.find('server {', pos)
    if start < 0:
        out.append(s[pos:])
        break
    out.append(s[pos:start])
    depth = 0
    end = None
    for i in range(start + len('server '), len(s)):
        if s[i] == '{': depth += 1
        elif s[i] == '}':
            depth -= 1
            if depth == 0:
                end = i
                break
    if end is None:
        raise SystemExit('Server block Nginx tidak seimbang')
    block = s[start:end]
    add = ''.join(route for path, route in blocks.items() if f'location {path}' not in block)
    out.append(block + add + '}')
    pos = end + 1
updated = ''.join(out)
if updated == s:
    print('[INFO] Rute HTTPUpgrade Nginx sudah lengkap.')
else:
    p.write_text(updated)
    print('[INFO] Rute HTTPUpgrade ditambahkan ke server block Nginx yang belum memilikinya.')
PYROUTES

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

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
XRAY PANEL (AYAH-ALMA)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Domain layanan       : ${domain}
Sertifikat           : ${CERT_DOMAIN}
Sertifikat metode    : Let's Encrypt HTTP-01 Webroot

WebSocket:
VMess WS TLS         : 443 /vmess -> 127.0.0.1:23456
VMess WS non-TLS     : 80  /vmess -> 127.0.0.1:23457
VLESS WS TLS         : 443 /vless -> 127.0.0.1:14016
VLESS WS non-TLS     : 80  /vless -> 127.0.0.1:14017
Trojan WS TLS        : 443 /trojan-ws -> 127.0.0.1:25432
Trojan WS non-TLS    : 80  /trojan-ws -> 127.0.0.1:25432

HTTPUpgrade (Nginx port 80 dan 443):
VMess HTTPUpgrade    : /upvmess  -> 127.0.0.1:14019
VLESS HTTPUpgrade    : /upvless  -> 127.0.0.1:14018
Trojan HTTPUpgrade   : /uptrojan -> 127.0.0.1:14020

Konfigurasi Xray     : /etc/xray/config.json
Konfigurasi Nginx    : /etc/nginx/conf.d/xray.conf
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
echo -e "NGINX Config   : /etc/nginx/conf.d/xray.conf"
echo -e "TLS Certificate: ${CERT_DOMAIN}"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
