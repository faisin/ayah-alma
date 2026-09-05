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
echo "  x. Kembali / Keluar"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Pilih menu [1, x]: " menu_pilihan

if [[ "$menu_pilihan" == "x" || "$menu_pilihan" == "X" ]]; then
    m-ssh
    exit 0
fi

if [[ "$menu_pilihan" == "1" ]]; then
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
else
    echo "Pilihan tidak valid!"
    exit 1
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
SSH ACCOUNT INFORMATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Username     : $user
Password     : $pass
Expired      : $EXP
Limit Device : $limit_device

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SERVER INFORMATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Domain       : $DOMAIN
IP VPS       : $IP

OpenSSH      : 22
Dropbear     : 109, 143
SSH WS       : 2082
SSH WSS      : 2096
UdpSSH       : 1-65535
BadVPN       : 7300

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CONNECTION FORMAT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

UDP CUSTOM
$DOMAIN:1-65535@$user:$pass

SSH WS
$DOMAIN:2082@$user:$pass

SSH WSS
$DOMAIN:2096@$user:$pass

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PAYLOAD WEBSOCKET
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

GET / HTTP/1.1[crlf]
Host: $DOMAIN[crlf]
Upgrade: websocket[crlf]
Connection: Upgrade[crlf]
[crlf]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PAYLOAD ENHANCED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

GET / HTTP/1.1[crlf]
Host: [host][crlf]
[crlf]
PATCH / HTTP/1.1[crlf]
Host: $DOMAIN[crlf]
Upgrade: websocket[crlf]
Connection: Upgrade[crlf]
[crlf][split]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Saved File : $ACCOUNT_FILE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

clear
cat "$ACCOUNT_FILE"
