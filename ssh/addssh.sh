#!/bin/bash

clear

DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
IP=$(curl -s ipv4.icanhazip.com)

if [[ -z "$DOMAIN" ]]; then
DOMAIN="$IP"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      MENU SSH ACCOUNT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1. Buat Akun SSH Reguler"
echo "  2. Buat Akun SSH Trial (1 Hari)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Pilih menu [1-2]: " menu_pilihan

if [[ "$menu_pilihan" == "2" ]]; then
    user="trial-$(</dev/urandom tr -dc 'a-z0-9' | head -c 4)"
    pass="$user"
    days="1"
    limit_device="1"
    
    while id "$user" &>/dev/null; do
        user="trial-$(</dev/urandom tr -dc 'a-z0-9' | head -c 4)"
        pass="$user"
    done
else
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "      CREATE SSH ACCOUNT"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    read -p "Username      : " user

    if id "$user" &>/dev/null; then
    echo ""
    echo "[ ERROR ] User already exists!"
    echo ""
    exit 1
    fi

    read -s -p "Password      : " pass
    echo ""

    read -p "Expired Days  : " days

    if ! [[ "$days" =~ ^[0-9]+$ ]]; then
    echo ""
    echo "[ ERROR ] Invalid expiration days!"
    echo ""
    exit 1
    fi

    read -p "Limit Device  : " limit_device

    if ! [[ "$limit_device" =~ ^[0-9]+$ ]]; then
        limit_device="1"
    fi
fi

EXP=$(date -d "$days days" +%Y-%m-%d)

useradd \
    -e "$EXP" \
    -m \
    -s /bin/bash \
    "$user"

id "$user" >/dev/null 2>&1 || {
    echo "[ERROR] Failed to create user!"
    exit 1
}

echo "$user:$pass" | chpasswd || {
    echo "[ERROR] Failed to set password!"
    exit 1
}

mkdir -p /root/accounts

ACCOUNT_FILE="/root/accounts/${user}.txt"

cat > "$ACCOUNT_FILE" <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SSH ACCOUNT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Username     : $user
Password     : $pass
Expired      : $EXP
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

Payload WS

GET / HTTP/1.1[crlf]
Host: $DOMAIN[crlf]
Upgrade: websocket[crlf]
Connection: Upgrade[crlf]
[crlf]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Payload Enhanced

GET / HTTP/1.1[crlf]
Host: [host][crlf]
[crlf]
PATCH / HTTP/1.1[crlf]
Host: $DOMAIN[crlf]
Upgrade: websocket[crlf]
Connection: Upgrade[crlf]
[crlf][split]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "       SSH ACCOUNT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Username       : $user"
echo "Password       : $pass"
echo "Expired        : $EXP"
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
echo "Payload WS"
echo ""
echo "GET / HTTP/1.1[crlf]"
echo "Host: $DOMAIN[crlf]"
echo "Upgrade: websocket[crlf]"
echo "Connection: Upgrade[crlf]"
echo "[crlf]"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Payload Enhanced"
echo ""
echo "GET / HTTP/1.1[crlf]"
echo "Host: [host][crlf]"
echo "[crlf]"
echo "PATCH / HTTP/1.1[crlf]"
echo "Host: $DOMAIN[crlf]"
echo "Upgrade: websocket[crlf]"
echo "Connection: Upgrade[crlf]"
echo "[crlf][split]"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Saved To:"
echo "$ACCOUNT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
