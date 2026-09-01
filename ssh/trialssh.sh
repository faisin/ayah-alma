#!/bin/bash

clear

DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
IP=$(curl -s ipv4.icanhazip.com)

if [[ -z "$DOMAIN" ]]; then
DOMAIN="$IP"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      CREATE TRIAL SSH"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Membuat username acak otomatis (contoh: trial-xxxx)
user="trial-$(</dev/urandom tr -dc 'a-z0-9' | head -c 4)"

# Password otomatis disamakan dengan username agar praktis
pass="$user"

# Masa aktif trial otomatis 1 hari
days="1"
limit_device="1"

EXP=$(date -d "$days days" +%Y-%m-%d)

useradd \
    -e "$EXP" \
    -m \
    -s /bin/bash \
    "$user"

id "$user" >/dev/null 2>&1 || {
    echo "[ERROR] Failed to create trial user!"
    exit 1
}

echo "$user:$pass" | chpasswd || {
    echo "[ERROR] Failed to set password!"
    exit 1
}

mkdir -p /root/accounts

ACCOUNT_FILE="/root/accounts/${user}.txt"

cat > "$ACCOUNT_FILE" <<'EOF_TEXT'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SSH TRIAL ACCOUNT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Username     : $user
Password     : $pass
Expired      : $EXP (1 Hari)
Limit Device : $limit_device

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Domain   : $DOMAIN
IP VPS   : $IP

OpenSSH  : 22
Dropbear : 109,143
SSH WS   : 2082
SSH WSS  : 2096
UdpSSH   : 1-65535
BadVPN   : 7300

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SSH UDP CUSTOM

$DOMAIN:1-65535@$user:$pass

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SSH WS

$DOMAIN:2082@$user:$pass

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SSH WSS

$DOMAIN:2096@$user:$pass

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Payload WSS / WS

GET /ssh-wss HTTP/1.1[crlf]Host: $DOMAIN[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF_TEXT

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "     SSH TRIAL ACCOUNT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Username       : $user"
echo "Password       : $pass"
echo "Expired        : $EXP (1 Hari)"
echo "Limit Device   : $limit_device"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Domain         : $DOMAIN"
echo "IP VPS         : $IP"
echo ""
echo "OpenSSH        : 22"
echo "Dropbear       : 109,143"
echo "SSH WS         : 2082"
echo "SSH WSS        : 2096"
echo "UdpSSH         : 1-65535"
echo "BadVPN UDPGW   : 7300"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "SSH UDP CUSTOM"
echo "$DOMAIN:1-65535@$user:$pass"
echo ""
echo "SSH WS"
echo "$DOMAIN:2082@$user:$pass"
echo ""
echo "SSH WSS"
echo "$DOMAIN:2096@$user:$pass"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Payload WSS / WS"
echo ""
echo "GET /ssh-wss HTTP/1.1[crlf]Host: $DOMAIN[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Saved To:"
echo "$ACCOUNT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

