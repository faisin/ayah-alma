#!/bin/bash
# Add VLESS Account - by Ayah Alma
set -e

clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[44;1;39m        Add VLESS Account        \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

# ambil domain
domain=$(cat /etc/xray/domain)

# public port nginx
tls="443"
none="80"
grpc="443"

# input username dengan validasi alfanumerik
until [[ $user =~ ^[a-zA-Z0-9_]+$ ]]; do
    read -rp "Username : " user
done

read -rp "Expired (days): " masaaktif

# --- TAMBAHAN INPUT LIMIT DEVICE ---
read -rp "Limit Device (Contoh: 2): " limit_device
if [[ -z "$limit_device" ]]; then
    limit_device="1"
fi
# ----------------------------------

uuid=$(cat /proc/sys/kernel/random/uuid)
exp=$(date -d "$masaaktif days" +"%Y-%m-%d")

# validasi config lama
if ! jq empty /etc/xray/config.json >/dev/null 2>&1; then
    echo ""
    echo "ERROR: config.json invalid!"
    exit 1
fi

# cek duplicate user
CLIENT_EXISTS=$(jq -r '.inbounds[].settings.clients[]?.email' /etc/xray/config.json | grep -w "$user" | wc -l)

if [[ ${CLIENT_EXISTS} == '1' ]]; then
    echo ""
    echo "ERROR: User already exists!"
    exit 1
fi

# backup config
cp /etc/xray/config.json /etc/xray/config.json.bak

# temp file
tmpfile=$(mktemp)

# inject user ke config untuk semua inbound vless
if ! jq --arg uuid "$uuid" --arg user "$user" '
(.inbounds[] | select(.tag=="vless-ws-tls").settings.clients) +=
[{"id":$uuid,"email":$user}] |

(.inbounds[] | select(.tag=="vless-ws-nontls").settings.clients) +=
[{"id":$uuid,"email":$user}] |

(.inbounds[] | select(.tag=="vless-grpc").settings.clients) +=
[{"id":$uuid,"email":$user}]
' /etc/xray/config.json > "$tmpfile"; then

    echo ""
    echo "ERROR: Failed inject config!"
    rm -f "$tmpfile"
    exit 1

fi

# cek file kosong
if [[ ! -s "$tmpfile" ]]; then
    echo ""
    echo "ERROR: Config generated empty!"
    rm -f "$tmpfile"
    exit 1
fi

# validasi json
if ! jq empty "$tmpfile" >/dev/null 2>&1; then
    echo ""
    echo "ERROR: Invalid JSON!"
    rm -f "$tmpfile"
    exit 1
fi

# replace config
mv "$tmpfile" /etc/xray/config.json

# test config xray
if ! xray -test -config /etc/xray/config.json >/dev/null 2>&1; then

    echo ""
    echo "ERROR: Xray config failed!"
    echo "Restoring backup config..."

    cp /etc/xray/config.json.bak /etc/xray/config.json

    exit 1

fi

# restart xray
systemctl restart xray

# cek status xray
if ! systemctl is-active --quiet xray; then

    echo ""
    echo "ERROR: Xray failed start!"
    echo "Restoring backup config..."

    cp /etc/xray/config.json.bak /etc/xray/config.json

    systemctl restart xray

    exit 1

fi

# simpan database user (termasuk limit device)
echo "${user} ${exp} ${uuid} ${limit_device}" >> /etc/xray/vless.db

# generate vless link
vlesslink1="vless://${uuid}@${domain}:${tls}?encryption=none&security=tls&sni=${domain}&type=ws&host=${domain}&path=%2Fvless#${user}"

vlesslink2="vless://${uuid}@${domain}:${none}?encryption=none&type=ws&host=${domain}&path=%2Fvless#${user}"

vlesslink3="vless://${uuid}@${domain}:${grpc}?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=${domain}#${user}"

clear

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[44;1;39m        XRAY VLESS ACCOUNT       \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Remarks        : ${user}"
echo -e "Domain         : ${domain}"
echo -e "Port TLS       : ${tls}"
echo -e "Port none TLS  : ${none}"
echo -e "Port gRPC      : ${grpc}"
echo -e "UUID           : ${uuid}"
echo -e "Limit Device   : ${limit_device}"
echo -e "Encryption     : none"
echo -e "Network        : ws / grpc"
echo -e "Path           : /vless"
echo -e "ServiceName    : vless-grpc"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Link TLS       :"
echo -e "${vlesslink1}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Link none TLS  :"
echo -e "${vlesslink2}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Link gRPC      :"
echo -e "${vlesslink3}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Expired On     : ${exp}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

echo ""
echo "Database User  : /etc/xray/vless.db"
echo ""

read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu..."

menu
