#!/bin/bash
# Trial VMess Account - by Ayah Alma
set -e

clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[44;1;39m        PILIH DURASI TRIAL       \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e " [1] Trial 1 Jam"
echo -e " [2] Trial 2 Jam"
echo -e " [3] Trial 3 Jam"
echo -e " [4] Trial 4 Jam"
echo -e " [5] Trial 5 Jam"
echo -e " [6] Trial 24 Jam (1 Hari)"
echo -e " [x] Kembali ke Menu"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
read -rp "Pilih durasi trial [1-6, x]: " durasi

if [[ "$durasi" == "x" || "$durasi" == "X" ]]; then
    /usr/bin/m-vmess 2>/dev/null || bash /etc/ayah-alma/xray/m-vmess
    exit 0
fi

case $durasi in
    1)
        masaaktif="1 Jam"
        exp=$(date -d "+1 hours" +"%Y-%m-%d %H:%M:%S")
        ;;
    2)
        masaaktif="2 Jam"
        exp=$(date -d "+2 hours" +"%Y-%m-%d %H:%M:%S")
        ;;
    3)
        masaaktif="3 Jam"
        exp=$(date -d "+3 hours" +"%Y-%m-%d %H:%M:%S")
        ;;
    4)
        masaaktif="4 Jam"
        exp=$(date -d "+4 hours" +"%Y-%m-%d %H:%M:%S")
        ;;
    5)
        masaaktif="5 Jam"
        exp=$(date -d "+5 hours" +"%Y-%m-%d %H:%M:%S")
        ;;
    6)
        masaaktif="24 Jam"
        exp=$(date -d "+1 days" +"%Y-%m-%d")
        ;;
    *)
        echo "Pilihan tidak valid!"
        exit 1
        ;;
esac

# Generate user random khusus trial
user="trial-$(</dev/urandom tr -dc 'a-z0-9' | head -c 4)"
while jq -r '.inbounds[].settings.clients[]?.email' /etc/xray/config.json | grep -w "$user" >/dev/null; do
    user="trial-$(</dev/urandom tr -dc 'a-z0-9' | head -c 4)"
done

limit_device="1"
domain=$(cat /etc/xray/domain)
tls="443"
none="80"
grpc="443"
uuid=$(cat /proc/sys/kernel/random/uuid)

# validasi config lama
if ! jq empty /etc/xray/config.json >/dev/null 2>&1; then
    echo "ERROR: config.json invalid!"
    exit 1
fi

# backup config
cp /etc/xray/config.json /etc/xray/config.json.bak
tmpfile=$(mktemp)

# inject user ke config
if ! jq --arg uuid "$uuid" --arg user "$user" '
(.inbounds[] | select(.tag=="vmess-ws-tls").settings.clients) +=
[{"id":$uuid,"alterId":0,"email":$user}] |

(.inbounds[] | select(.tag=="vmess-ws-nontls").settings.clients) +=
[{"id":$uuid,"alterId":0,"email":$user}] |

(.inbounds[] | select(.tag=="vmess-grpc").settings.clients) +=
[{"id":$uuid,"alterId":0,"email":$user}]
' /etc/xray/config.json > "$tmpfile"; then
    rm -f "$tmpfile"
    exit 1
fi

mv "$tmpfile" /etc/xray/config.json
systemctl restart xray

# simpan database user
echo "${user} ${exp} ${uuid} ${limit_device}" >> /etc/xray/vmess.db

# generate vmess links
vmess_json_tls="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${domain}\",\"port\":\"${tls}\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${domain}\",\"path\":\"/vmess\",\"tls\":\"tls\",\"sni\":\"${domain}\"}"
vmess_json_none="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${domain}\",\"port\":\"${none}\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${domain}\",\"path\":\"/vmess\",\"tls\":\"none\"}"
vmess_json_grpc="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${domain}\",\"port\":\"${grpc}\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"grpc\",\"type\":\"gun\",\"host\":\"${domain}\",\"path\":\"vmess-grpc\",\"tls\":\"tls\",\"sni\":\"${domain}\"}"

vmesslink1="vmess://$(echo "$vmess_json_tls" | base64 -w 0)"
vmesslink2="vmess://$(echo "$vmess_json_none" | base64 -w 0)"
vmesslink3="vmess://$(echo "$vmess_json_grpc" | base64 -w 0)"

clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[44;1;39m       XRAY VMESS TRIAL ACCOUNT    \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Remarks        : ${user}"
echo -e "Domain         : ${domain}"
echo -e "UUID           : ${uuid}"
echo -e "Limit Device   : ${limit_device}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Link TLS       :\n${vmesslink1}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Link none TLS  :\n${vmesslink2}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Link gRPC      :\n${vmesslink3}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Expired On     : ${exp} (${masaaktif})"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu..."
/usr/bin/m-vmess 2>/dev/null || bash /etc/ayah-alma/xray/m-vmess

