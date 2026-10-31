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

# Cek status SSH WebSocket dan WSS
if systemctl is-active --quiet dropbear-ws; then
    echo " [✓] SSH WS   : Running"
else
    echo " [✗] SSH WS   : Not Running"
fi

if systemctl is-active --quiet dropbear-wss; then
    echo " [✓] SSH WSS  : Running"
else
    echo " [✗] SSH WSS  : Not Running"
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
