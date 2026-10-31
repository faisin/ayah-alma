#!/bin/bash

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   RESTART SSH SERVICES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Restarting services..."

# Restart OpenSSH
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null

# Restart Dropbear
systemctl restart dropbear 2>/dev/null

# Restart Websocket SSH (jika ada)
systemctl restart ws-stunnel 2>/dev/null || systemctl restart ssh-ws 2>/dev/null

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " SERVICES SUCCESSFULLY RESTARTED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

