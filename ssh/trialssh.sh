#!/bin/bash

clear

# TAMPILKAN MENU TERLEBIH DAHULU AGAR TIDAK ADA JEDA/BLANK
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      PILIH DURASI TRIAL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1. Trial 1 Jam"
echo "  2. Trial 3 Jam"
echo "  3. Trial 24 Jam (1 Hari)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Pilih durasi [1-3]: " durasi

# SETELAH INPUT, BARU SISTEM MEMPROSES DATA
case $durasi in
    1)
        days="1"
        ket_waktu="1 Jam"
        ;;
    2)
        days="1"
        ket_waktu="3 Jam"
        ;;
    3)
        days="1"
        ket_waktu="1 Hari"
        ;;
    *)
        days="1"
        ket_waktu="1 Hari"
        ;;
esac

echo ""
echo "Mohon tunggu, sedang memproses akun trial..."
echo ""

# AMBIL DATA DOMAIN & IP (Diberi batasan waktu agar tidak error/hang)
DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
IP=$(curl -s --max-time 3 ipv4.icanhazip.com)

if [[ -z "$DOMAIN" ]]; then
DOMAIN="$IP"
fi

# GENERATE USER & PASSWORD
user="trial-$(</dev/urandom tr -dc 'a-z0-9' | head -c 4)"
pass="$user"
limit_device="1"

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
SSH TRIAL ACCOUNT ($ket_waktu)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Username     : $user
Password     : $pass
Expired      : $EXP ($ket_waktu)
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
echo "Durasi Trial   : $ket_waktu"
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
