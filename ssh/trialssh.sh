#!/bin/bash

clear

DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
IP=$(curl -s ipv4.icanhazip.com)

if [[ -z "$DOMAIN" ]]; then
DOMAIN="$IP"
fi

# Generate random username & password untuk trial (contoh: trial-abcd)
user="trial-$(</dev/urandom tr -dc 'a-z0-9' | head -c 4)"
pass="$user"
days="1"
limit_device="1"

# Memastikan username unik (belum ada di sistem)
while id "$user" &>/dev/null; do
    user="trial-$(</dev/urandom tr -dc 'a-z0-9' | head -c 4)"
    pass="$user"
done

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

cat > "$ACCOUNT_FILE" <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SSH TRIAL ACCOUNT (1 DAY)
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
EOF

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
echo "Saved To:"
echo "$ACCOUNT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
