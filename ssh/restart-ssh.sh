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

# Restart SSH WebSocket bridges
systemctl restart dropbear-ws 2>/dev/null
systemctl restart dropbear-wss 2>/dev/null

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " SERVICES SUCCESSFULLY RESTARTED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

