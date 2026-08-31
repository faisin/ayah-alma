#!/bin/bash
# Install Nginx Reverse Proxy - by Ayah-Alma
# Converted for Ayah-Alma Project

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

BASE_DIR="/root/ayah-alma"

if [[ ! -d "$BASE_DIR" ]]; then
    echo -e "${RED}[ERROR] Repo ayah-alma not found!${NC}"
    exit 1
fi

clear

echo -e "${GREEN}▶️ Installing NGINX Reverse Proxy...${NC}"
sleep 1

# INSTALL NGINX
apt update -y

apt install -y \
nginx \
curl \
wget

# REMOVE DEFAULT CONFIG
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default

# CREATE DIR
mkdir -p /etc/nginx/conf.d

# COPY MAIN NGINX CONFIG
if [[ ! -f "$BASE_DIR/config/nginx.conf" ]]; then
    echo -e "${RED}[ERROR] nginx.conf not found in ayah-alma repository!${NC}"
    exit 1
fi

cp "$BASE_DIR/config/nginx.conf" /etc/nginx/nginx.conf

# PERMISSION
chmod 644 /etc/nginx/nginx.conf

# TEST CONFIG
echo -e "${GREEN}🧪 Testing Nginx Config...${NC}"

nginx -t || {
    echo -e "${RED}❌ Nginx config error!${NC}"
    exit 1
}

# ENABLE SERVICE
systemctl enable nginx
systemctl restart nginx

sleep 2

systemctl is-active --quiet nginx || {
    echo -e "${RED}[ERROR] NGINX failed to start!${NC}"
    exit 1
}

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ NGINX INSTALLED SUCCESSFULLY${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Main Config   : /etc/nginx/nginx.conf"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
