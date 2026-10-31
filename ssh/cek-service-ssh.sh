#!/bin/bash

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "    CHECK SSH SERVICES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Cek status Dropbear
if systemctl is-active --quiet dropbear; then
    echo " [✓] Dropbear : Running"
else
    echo " [✗] Dropbear : Not Running (Dead)"
fi

# Cek status SSH (OpenSSH)
if systemctl is-active --quiet ssh || systemctl is-active --quiet sshd; then
    echo " [✓] OpenSSH  : Running"
else
    echo " [✗] OpenSSH  : Not Running (Dead)"
fi

# Cek status Websocket (jika menggunakan layanan python/stunnel/ws)
if systemctl is-active --quiet ws-stunnel || systemctl is-active --quiet ssh-ws; then
    echo " [✓] SSH WSS  : Running"
else
    echo " [!] SSH WSS  : Check Manual / Not Active"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  x. Kembali ke Menu Utama"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Tekan [x] untuk kembali: " pilihan

if [[ "$pilihan" == "x" || "$pilihan" == "X" ]]; then
    /usr/bin/m-ssh 2>/dev/null || bash /etc/ayah-alma/ssh/m-ssh
    exit 0
fi
