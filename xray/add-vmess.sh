#!/bin/bash

# ================================================================
# AYAH-ALMA
# ADD VMESS ACCOUNT
# ================================================================

set -u

CONFIG="/etc/xray/config.json"
DB="/etc/xray/vmess.db"
DOMAIN_FILE="/etc/xray/domain"

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

die() {
    error "$*"
    exit 1
}

# ================================================================
# ROOT CHECK
# ================================================================

[[ $EUID -eq 0 ]] || die "Script harus dijalankan sebagai root."

# ================================================================
# DEPENDENCY CHECK
# ================================================================

command -v jq >/dev/null 2>&1 \
    || die "jq belum terinstall."

command -v uuidgen >/dev/null 2>&1 \
    || die "uuidgen belum terinstall."

command -v xray >/dev/null 2>&1 \
    || die "Binary xray tidak ditemukan."

[[ -f "$CONFIG" ]] \
    || die "Config Xray tidak ditemukan: $CONFIG"

# ================================================================
# DOMAIN
# ================================================================

if [[ -s "$DOMAIN_FILE" ]]; then
    DOMAIN=$(head -n1 "$DOMAIN_FILE" | tr -d '[:space:]')
else
    DOMAIN=$(hostname -f 2>/dev/null || hostname)
fi

[[ -n "$DOMAIN" ]] \
    || die "Domain tidak ditemukan."

# ================================================================
# DATABASE
# ================================================================

mkdir -p "$(dirname "$DB")"

touch "$DB"

chmod 600 "$DB"

# ================================================================
# USERNAME
# ================================================================

echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}          ADD VMESS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

read -rp "Username : " USERNAME

USERNAME=$(echo "$USERNAME" | tr -d '[:space:]')

[[ -n "$USERNAME" ]] \
    || die "Username tidak boleh kosong."

# Hanya karakter aman.
if [[ ! "$USERNAME" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    die "Username hanya boleh menggunakan huruf, angka, titik, garis bawah, dan tanda -."
fi

# ================================================================
# DUPLICATE CHECK
# ================================================================

if awk -v user="$USERNAME" '
    $1 == user {
        found=1
        exit
    }
    END {
        exit !found
    }
' "$DB"; then

    die "Username $USERNAME sudah terdaftar di VMess."

fi

# Cek juga langsung ke config Xray.
if jq -e \
    --arg email "$USERNAME" \
    '
    [
        .inbounds[]?
        | select(.protocol == "vmess")
        | .settings.clients[]?
        | select(.email == $email)
    ] | length > 0
    ' "$CONFIG" >/dev/null 2>&1; then

    die "Username $USERNAME sudah ada di config Xray."

fi

# ================================================================
# MASA AKTIF
# ================================================================

read -rp "Masa aktif (hari) [30] : " MASAAKTIF

if [[ -z "$MASAAKTIF" ]]; then
    MASAAKTIF=30
fi

[[ "$MASAAKTIF" =~ ^[0-9]+$ ]] \
    || die "Masa aktif harus berupa angka."

(( MASAAKTIF >= 1 )) \
    || die "Masa aktif minimal 1 hari."

# ================================================================
# LIMIT DEVICE
# ================================================================

read -rp "Limit Device [2] : " LIMIT_DEVICE

if [[ -z "$LIMIT_DEVICE" ]]; then
    LIMIT_DEVICE=2
fi

[[ "$LIMIT_DEVICE" =~ ^[0-9]+$ ]] \
    || die "Limit Device harus berupa angka."

(( LIMIT_DEVICE >= 1 )) \
    || die "Limit Device minimal 1."

# ================================================================
# EXPIRY
# ================================================================

EXP_DATE=$(date -d "+${MASAAKTIF} days" +"%Y-%m-%d" 2>/dev/null)

[[ -n "$EXP_DATE" ]] \
    || die "Gagal menghitung tanggal expired."

# ================================================================
# UUID
# ================================================================

UUID=$(uuidgen)

[[ -n "$UUID" ]] \
    || die "Gagal membuat UUID."

# ================================================================
# BACKUP CONFIG
# ================================================================

BACKUP="${CONFIG}.bak-add-vmess"

cp -a "$CONFIG" "$BACKUP" \
    || die "Gagal membuat backup config Xray."

# ================================================================
# ADD CLIENT KE SEMUA INBOUND VMESS
# ================================================================

TMP_CONFIG="${CONFIG}.tmp"

if ! jq \
    --arg id "$UUID" \
    --arg email "$USERNAME" \
    '
    .inbounds |= map(
        if .protocol == "vmess" then

            .settings.clients =
                (
                    (.settings.clients // [])
                    + [
                        {
                            "id": $id,
                            "alterId": 0,
                            "email": $email
                        }
                    ]
                )

        else
            .
        end
    )
    ' \
    "$CONFIG" > "$TMP_CONFIG"; then

    rm -f "$TMP_CONFIG"
    die "Gagal mengubah config Xray."

fi

# ================================================================
# CEK DUPLIKASI UUID
# ================================================================

UUID_COUNT=$(jq \
    --arg id "$UUID" \
    '
    [
        .inbounds[]?
        | select(.protocol == "vmess")
        | .settings.clients[]?
        | select(.id == $id)
    ] | length
    ' \
    "$TMP_CONFIG")

if [[ "$UUID_COUNT" -lt 1 ]]; then

    rm -f "$TMP_CONFIG"

    cp -a "$BACKUP" "$CONFIG"

    die "UUID tidak berhasil dimasukkan ke config Xray."

fi

# ================================================================
# INSTALL CONFIG
# ================================================================

mv "$TMP_CONFIG" "$CONFIG"

chmod 600 "$CONFIG"

# ================================================================
# TEST CONFIG XRAY
# ================================================================

info "Memeriksa konfigurasi Xray..."

if ! xray run -test -config "$CONFIG" >/tmp/xray-add-vmess-test.log 2>&1; then

    error "Konfigurasi Xray tidak valid."

    cat /tmp/xray-add-vmess-test.log

    cp -a "$BACKUP" "$CONFIG"

    rm -f /tmp/xray-add-vmess-test.log

    die "Config dikembalikan ke kondisi sebelum penambahan akun."

fi

rm -f /tmp/xray-add-vmess-test.log

# ================================================================
# SIMPAN DATABASE
#
# FORMAT:
# username expiry uuid limit_device
# ================================================================

printf '%s %s %s %s\n' \
    "$USERNAME" \
    "$EXP_DATE" \
    "$UUID" \
    "$LIMIT_DEVICE" \
    >> "$DB"

chmod 600 "$DB"

# ================================================================
# RESTART XRAY
# ================================================================

if systemctl list-unit-files 2>/dev/null | grep -q '^xray.service'; then

    if ! systemctl restart xray; then

        error "Xray gagal restart."

        # Hapus entry database yang baru dibuat.
        sed -i \
            "\|^${USERNAME}[[:space:]]${EXP_DATE}[[:space:]]${UUID}[[:space:]]${LIMIT_DEVICE}$|d" \
            "$DB"

        # Kembalikan config.
        cp -a "$BACKUP" "$CONFIG"

        systemctl restart xray >/dev/null 2>&1 || true

        die "Pembuatan akun dibatalkan karena Xray gagal restart."

    fi

else

    warn "xray.service tidak ditemukan."
    warn "Config sudah diperbarui tetapi service tidak direstart."

fi

# ================================================================
# VERIFY CLIENT
# ================================================================

VERIFY_COUNT=$(jq \
    --arg email "$USERNAME" \
    --arg id "$UUID" \
    '
    [
        .inbounds[]?
        | select(.protocol == "vmess")
        | .settings.clients[]?
        | select(.email == $email and .id == $id)
    ] | length
    ' \
    "$CONFIG")

if [[ "$VERIFY_COUNT" -lt 1 ]]; then

    error "Verifikasi client gagal."

    # Bersihkan database.
    sed -i \
        "\|^${USERNAME}[[:space:]]${EXP_DATE}[[:space:]]${UUID}[[:space:]]${LIMIT_DEVICE}$|d" \
        "$DB"

    cp -a "$BACKUP" "$CONFIG"

    systemctl restart xray >/dev/null 2>&1 || true

    die "Akun VMess tidak berhasil diverifikasi."

fi

# ================================================================
# VMESS LINK GENERATOR
# ================================================================

make_vmess_link() {

    local name="$1"
    local port="$2"
    local net="$3"
    local path="$4"
    local host="$5"
    local tls="$6"
    local type="$7"
    local service="$8"

    local json
    local encoded

    if [[ "$net" == "grpc" ]]; then

        json=$(jq -nc \
            --arg v "2" \
            --arg ps "$name" \
            --arg add "$DOMAIN" \
            --arg port "$port" \
            --arg id "$UUID" \
            --arg aid "0" \
            --arg net "grpc" \
            --arg type "none" \
            --arg host "$host" \
            --arg path "" \
            --arg tls "$tls" \
            --arg serviceName "$service" \
            '{
                v: $v,
                ps: $ps,
                add: $add,
                port: $port,
                id: $id,
                aid: $aid,
                net: $net,
                type: $type,
                host: $host,
                path: $path,
                tls: $tls,
                scy: "auto",
                sni: $host,
                alpn: "h2",
                fp: "chrome",
                grpcOpts: {
                    serviceName: $serviceName
                }
            }')

    else

        json=$(jq -nc \
            --arg v "2" \
            --arg ps "$name" \
            --arg add "$DOMAIN" \
            --arg port "$port" \
            --arg id "$UUID" \
            --arg aid "0" \
            --arg net "$net" \
            --arg type "$type" \
            --arg host "$host" \
            --arg path "$path" \
            --arg tls "$tls" \
            '{
                v: $v,
                ps: $ps,
                add: $add,
                port: $port,
                id: $id,
                aid: $aid,
                net: $net,
                type: $type,
                host: $host,
                path: $path,
                tls: $tls,
                scy: "auto",
                sni: $host,
                alpn: "http/1.1",
                fp: "chrome"
            }')

    fi

    encoded=$(printf '%s' "$json" | base64 -w 0)

    printf 'vmess://%s\n' "$encoded"
}

# ================================================================
# DETECT PUBLIC PORTS
#
# VMess WS TLS      -> 443
# VMess WS NON TLS  -> 80
# VMess GRPC TLS    -> 443
#
# Port backend Xray tidak digunakan sebagai port client.
# ================================================================

WS_TLS_PORT="443"
WS_NONTLS_PORT="80"
GRPC_PORT="443"

# ================================================================
# DETECT WS PATH
# ================================================================

WS_TLS_PATH=$(jq -r '
    .inbounds[]?
    | select(
        .tag == "vmess-ws-tls"
        or (
            .protocol == "vmess"
            and .streamSettings.network == "ws"
            and .streamSettings.security == "tls"
        )
    )
    | .streamSettings.wsSettings.path // empty
' "$CONFIG" | head -n1)

WS_NONTLS_PATH=$(jq -r '
    .inbounds[]?
    | select(
        .tag == "vmess-ws-nontls"
        or (
            .protocol == "vmess"
            and .streamSettings.network == "ws"
            and .streamSettings.security != "tls"
        )
    )
    | .streamSettings.wsSettings.path // empty
' "$CONFIG" | head -n1)

GRPC_SERVICE=$(jq -r '
    .inbounds[]?
    | select(
        .tag == "vmess-grpc"
        or (
            .protocol == "vmess"
            and .streamSettings.network == "grpc"
        )
    )
    | .streamSettings.grpcSettings.serviceName // empty
' "$CONFIG" | head -n1)

[[ -n "$WS_TLS_PATH" ]] || WS_TLS_PATH="/vmess"

[[ -n "$WS_NONTLS_PATH" ]] || WS_NONTLS_PATH="/vmess"

[[ -n "$GRPC_SERVICE" ]] || GRPC_SERVICE="vmess-grpc"

# ================================================================
# OUTPUT
# ================================================================

echo
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}       VMESS ACCOUNT BERHASIL DIBUAT${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "Username       : ${CYAN}${USERNAME}${NC}"
echo -e "UUID           : ${CYAN}${UUID}${NC}"
echo -e "Expired        : ${CYAN}${EXP_DATE}${NC}"
echo -e "Limit Device   : ${CYAN}${LIMIT_DEVICE}${NC}"
echo -e "Domain         : ${CYAN}${DOMAIN}${NC}"
echo

echo -e "${YELLOW}VMess WS TLS${NC}"
make_vmess_link \
    "VMess-${USERNAME}-WS-TLS" \
    "$WS_TLS_PORT" \
    "ws" \
    "$WS_TLS_PATH" \
    "$DOMAIN" \
    "tls" \
    "none" \
    ""

echo

echo -e "${YELLOW}VMess WS NON TLS${NC}"
make_vmess_link \
    "VMess-${USERNAME}-WS-NTLS" \
    "$WS_NONTLS_PORT" \
    "ws" \
    "$WS_NONTLS_PATH" \
    "$DOMAIN" \
    "none" \
    "none" \
    ""

echo

echo -e "${YELLOW}VMess GRPC TLS${NC}"
make_vmess_link \
    "VMess-${USERNAME}-GRPC" \
    "$GRPC_PORT" \
    "grpc" \
    "" \
    "$DOMAIN" \
    "tls" \
    "none" \
    "$GRPC_SERVICE"

echo

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Database:${NC} $DB"
echo -e "${GREEN}Format  :${NC} username expiry uuid limit_device"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo

# ================================================================
# FINAL STATUS
# ================================================================

if systemctl is-active --quiet xray; then
    echo -e "${GREEN}Xray Status : ACTIVE${NC}"
else
    echo -e "${RED}Xray Status : NOT ACTIVE${NC}"
fi

echo -e "${GREEN}Limit Device tersimpan: ${LIMIT_DEVICE}${NC}"
echo

# ================================================================
# CLEANUP
# ================================================================

rm -f "$BACKUP"

# ================================================================
# WAIT
# ================================================================

if [[ -t 0 ]]; then
    read -n 1 -s -r -p "Tekan tombol apa saja untuk kembali..."
    echo
fi

exit 0
