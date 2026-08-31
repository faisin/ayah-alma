#!/bin/bash
# Add Trojan Account - by Ayah Alma
set -e

clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[44;1;39m        Add Trojan Account       \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

domain=$(cat /etc/xray/domain)

tls="443"
grpc="443"

until [[ $user =~ ^[a-zA-Z0-9_]+$ ]]; do
    read -rp "Username : " user
done

read -rp "Expired (days): " masaaktif

uuid=$(cat /proc/sys/kernel/random/uuid)
exp=$(date -d "$masaaktif days" +"%Y-%m-%d")

if ! jq empty /etc/xray/config.json >/dev/null 2>&1; then
    echo ""
    echo "ERROR: config.json invalid!"
    exit 1
fi

CLIENT_EXISTS=$(jq -r '.inbounds[].settings.clients[]?.email' /etc/xray/config.json | grep -w "$user" | wc -l)

if [[ ${CLIENT_EXISTS} == '1' ]]; then
    echo ""
    echo "ERROR: User already exists!"
    exit 1
fi

cp /etc/xray/config.json /etc/xray/config.json.bak
tmpfile=$(mktemp)

if ! jq --arg uuid "$uuid" --arg user "$user" '
(.inbounds[] | select(.tag=="trojan-ws-tls").settings.clients) +=
[{"password":$uuid,"email":$user}] |

(.inbounds[] | select(.tag=="trojan-grpc").settings.clients) +=
[{"password":$uuid,"email":$user}]
' /etc/xray/config.json > "$tmpfile"; then
    echo ""
    echo "ERROR: Failed inject config!"
    rm -f "$tmpfile"
    exit 1
fi

if [[ ! -s "$tmpfile" ]] || ! jq empty "$tmpfile" >/dev/null 2>&1; then
    echo ""
    echo "ERROR: Invalid JSON generated!"
    rm -f "$tmpfile"
    exit 1
fi

mv "$tmpfile" /etc/xray/config.json

if ! xray -test -config /etc/xray/config.json >/dev/null 2>&1; then
    echo ""
    echo "ERROR: Xray config failed! Restoring backup..."
    cp /etc/xray/config.json.bak /etc/xray/config.json
    exit 1
fi

systemctl restart xray

if ! systemctl is-active --quiet xray; then
    echo ""
    echo "ERROR: Xray failed start! Restoring backup..."
    cp /etc/xray/config.json.bak /etc/xray/config.json
    systemctl restart xray
    exit 1
fi

echo "${user} ${exp} ${uuid}" >> /etc/xray/trojan.db

trojanlink1="trojan://${uuid}@${domain}:${tls}?path=%2Ftrojan-ws&security=tls&type=ws&host=${domain}&sni=${domain}#${user}"
trojanlink2="trojan://${uuid}@${domain}:${grpc}?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=${domain}#${user}"

clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[44;1;39m       XRAY Trojan ACCOUNT       \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Remarks        : ${user}"
echo -e "Domain         : ${domain}"
echo -e "Port TLS       : ${tls}"
echo -e "Port gRPC      : ${grpc}"
echo -e "Password       : ${uuid}"
echo -e "Network        : ws / grpc"
echo -e "Path           : /trojan-ws"
echo -e "ServiceName    : trojan-grpc"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Link TLS       :\n${trojanlink1}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Link gRPC      :\n${trojanlink2}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Expired On     : ${exp}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo ""
echo "Database User  : /etc/xray/trojan.db"
echo ""

read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu..."
menu
