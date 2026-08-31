#!/bin/bash
set -e

clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[44;1;39m     Add Shadowsocks Account     \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

# ambil domain
domain=$(cat /etc/xray/domain)

# public nginx port
port_tls="443"
port_none="80"
port_grpc="443"

# input username
until [[ $user =~ ^[a-zA-Z0-9_]+$ ]]; do
    read -rp "Username : " user
done

# cek duplicate user
CLIENT_EXISTS=$(jq -r '.inbounds[].settings.clients[]?.email' /etc/xray/config.json | grep -w "$user" | wc -l)

if [[ ${CLIENT_EXISTS} == '1' ]]; then
    echo ""
    echo "ERROR: User already exists!"
    exit 1
fi

read -rp "Expired (days): " masaaktif

cipher="aes-128-gcm"
uuid=$(cat /proc/sys/kernel/random/uuid)
exp=$(date -d "$masaaktif days" +"%Y-%m-%d")

# validasi config lama
if ! jq empty /etc/xray/config.json >/dev/null 2>&1; then
    echo ""
    echo "ERROR: config.json invalid!"
    exit 1
fi

# backup config
cp /etc/xray/config.json /etc/xray/config.json.bak

# temp file
tmpfile=$(mktemp)

# inject user ke config
if ! jq --arg uuid "$uuid" --arg user "$user" --arg method "$cipher" '
(.inbounds[] | select(.tag=="ssws-ws-tls").settings.clients) +=
[{
    "password": $uuid,
    "method": $method,
    "email": $user
}] |

(.inbounds[] | select(.tag=="ssws-ws-nontls").settings.clients) +=
[{
    "password": $uuid,
    "method": $method,
    "email": $user
}] |

(.inbounds[] | select(.tag=="ssws-grpc").settings.clients) +=
[{
    "password": $uuid,
    "method": $method,
    "email": $user
}]
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

# simpan database user
echo "${user} ${exp} ${uuid}" >> /etc/xray/ssws.db

# encode password
ss_base64=$(echo -n "${cipher}:${uuid}" | base64 -w 0)

# generate ws tls link
sslink1="ss://${ss_base64}@${domain}:${port_tls}?plugin=xray-plugin%3Bpath%3D%2Fss-ws%3Bhost%3D${domain}%3Btls#${user}"

# generate ws nontls link
sslink2="ss://${ss_base64}@${domain}:${port_none}?plugin=xray-plugin%3Bpath%3D%2Fss-ws%3Bhost%3D${domain}#${user}"

# generate grpc link
sslink3="ss://${ss_base64}@${domain}:${port_grpc}?plugin=xray-plugin%3Bmode%3Dgun%3BserviceName%3Dss-grpc%3Bhost%3D${domain}%3Btls#${user}"

clear

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[44;1;39m      Shadowsocks ACCOUNT        \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Remarks       : ${user}"
echo -e "Domain        : ${domain}"
echo -e "Port TLS      : ${port_tls}"
echo -e "Port No TLS   : ${port_none}"
echo -e "Port gRPC     : ${port_grpc}"
echo -e "Password      : ${uuid}"
echo -e "Cipher        : ${cipher}"
echo -e "Network       : ws / grpc"
echo -e "Path          : /ss-ws"
echo -e "ServiceName   : ss-grpc"
echo -e "Expired On    : ${exp}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Link TLS      :"
echo -e "${sslink1}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Link None TLS :"
echo -e "${sslink2}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Link gRPC     :"
echo -e "${sslink3}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

echo ""
echo "Database User : /etc/xray/ssws.db"
echo ""

echo ""
read -n 1 -s -r -p "Tekan tombol apa saja untuk kembali ke menu..."
menu
