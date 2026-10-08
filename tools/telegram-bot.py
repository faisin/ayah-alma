#!/usr/bin/env python3
# ============================================================
# AYAH ALMA TELEGRAM BOT
# ============================================================

import os
import time
import subprocess
import requests

CONFIG_FILE = "/etc/ayah-alma/config/telegram.conf"

# ============================================================
# LOAD CONFIG
# ============================================================

def load_config():
    config = {}

    if not os.path.isfile(CONFIG_FILE):
        return config

    try:
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()

                if not line or line.startswith("#"):
                    continue

                if "=" not in line:
                    continue

                key, value = line.split("=", 1)

                key = key.strip()
                value = value.strip().strip('"').strip("'")

                config[key] = value

    except Exception as e:
        print(f"Gagal membaca konfigurasi: {e}")

    return config


CONFIG = load_config()

TOKEN = CONFIG.get("BOT_TOKEN", "")
ADMIN_CHAT_ID = CONFIG.get("ADMIN_CHAT_ID", "")

if not TOKEN:
    print("ERROR: BOT_TOKEN belum dikonfigurasi.")
    raise SystemExit(1)


API_URL = f"https://api.telegram.org/bot{TOKEN}/"


# ============================================================
# TELEGRAM API
# ============================================================

def telegram_request(method, data=None, timeout=35):
    try:
        response = requests.post(
            API_URL + method,
            json=data or {},
            timeout=timeout
        )

        result = response.json()

        if not result.get("ok"):
            print(f"Telegram API error: {result}")

        return result

    except Exception as e:
        print(f"Telegram connection error: {e}")
        return None


def send_message(chat_id, text, reply_markup=None):
    data = {
        "chat_id": chat_id,
        "text": text,
        "parse_mode": "Markdown"
    }

    if reply_markup:
        data["reply_markup"] = reply_markup

    return telegram_request("sendMessage", data)


def answer_callback(callback_id, text=""):
    return telegram_request(
        "answerCallbackQuery",
        {
            "callback_query_id": callback_id,
            "text": text,
            "show_alert": False
        }
    )


def edit_message(chat_id, message_id, text, reply_markup=None):
    data = {
        "chat_id": chat_id,
        "message_id": message_id,
        "text": text,
        "parse_mode": "Markdown"
    }

    if reply_markup:
        data["reply_markup"] = reply_markup

    return telegram_request("editMessageText", data)


# ============================================================
# PERMISSION
# ============================================================

def is_admin(chat_id):
    if not ADMIN_CHAT_ID:
        return False

    return str(chat_id) == str(ADMIN_CHAT_ID)


# ============================================================
# MAIN MENU
# ============================================================

def main_menu(chat_id=None):

    keyboard = [
        [
            {
                "text": "🌐 Produk / Layanan",
                "callback_data": "produk"
            }
        ],
        [
            {
                "text": "💳 Cara Order",
                "callback_data": "cara_order"
            }
        ],
        [
            {
                "text": "📞 Hubungi Admin",
                "url": "https://t.me/anindyaalmahyra"
            }
        ],
        [
            {
                "text": "ℹ️ Tentang Bot",
                "callback_data": "tentang"
            }
        ]
    ]

    if chat_id is not None and is_admin(chat_id):
        keyboard.append([
            {
                "text": "🔐 ADMIN PANEL",
                "callback_data": "admin"
            }
        ])

    return {
        "inline_keyboard": keyboard
    }


# ============================================================
# ADMIN MENU
# ============================================================

def admin_menu():

    return {
        "inline_keyboard": [

            [
                {
                    "text": "📊 Status Server",
                    "callback_data": "status_server"
                }
            ],

            [
                {
                    "text": "👥 Kelola Akun",
                    "callback_data": "kelola_akun"
                }
            ],

            [
                {
                    "text": "📦 Produk / Layanan",
                    "callback_data": "admin_produk"
                }
            ],

            [
                {
                    "text": "🧾 Pesanan",
                    "callback_data": "pesanan"
                }
            ],

            [
                {
                    "text": "💰 Pembayaran",
                    "callback_data": "pembayaran"
                }
            ],

            [
                {
                    "text": "⚙️ Pengaturan Bot",
                    "callback_data": "pengaturan_bot"
                }
            ],

            [
                {
                    "text": "🖥 Menu VPS",
                    "callback_data": "menu_vps"
                }
            ],

            [
                {
                    "text": "🔄 Restart Xray",
                    "callback_data": "restart_xray"
                }
            ],

            [
                {
                    "text": "🔄 Restart SSH",
                    "callback_data": "restart_ssh"
                }
            ],

            [
                {
                    "text": "⬅️ Menu Utama",
                    "callback_data": "back"
                }
            ]
        ]
    }


# ============================================================
# ACCOUNT MENU
# ============================================================

def account_menu():

    return {
        "inline_keyboard": [

            [
                {
                    "text": "🔵 VMess",
                    "callback_data": "akun_vmess"
                },
                {
                    "text": "🟢 VLESS",
                    "callback_data": "akun_vless"
                }
            ],

            [
                {
                    "text": "🟠 Trojan",
                    "callback_data": "akun_trojan"
                },
                {
                    "text": "🔐 SSH",
                    "callback_data": "akun_ssh"
                }
            ],

            [
                {
                    "text": "📋 Daftar Akun",
                    "callback_data": "daftar_akun"
                }
            ],

            [
                {
                    "text": "➕ Buat Akun",
                    "callback_data": "buat_akun"
                }
            ],

            [
                {
                    "text": "🗑 Hapus Akun",
                    "callback_data": "hapus_akun"
                }
            ],

            [
                {
                    "text": "🔄 Renew Akun",
                    "callback_data": "renew_akun"
                }
            ],

            [
                {
                    "text": "⬅️ Admin Panel",
                    "callback_data": "admin"
                }
            ]
        ]
    }


# ============================================================
# PRODUCT MENU
# ============================================================

def product_menu():

    return {
        "inline_keyboard": [

            [
                {
                    "text": "🔵 VMess",
                    "callback_data": "produk_vmess"
                }
            ],

            [
                {
                    "text": "🟢 VLESS",
                    "callback_data": "produk_vless"
                }
            ],

            [
                {
                    "text": "🟠 Trojan",
                    "callback_data": "produk_trojan"
                }
            ],

            [
                {
                    "text": "🔐 SSH",
                    "callback_data": "produk_ssh"
                }
            ],

            [
                {
                    "text": "⬅️ Admin Panel",
                    "callback_data": "admin"
                }
            ]
        ]
    }


# ============================================================
# SERVER STATUS
# ============================================================

def get_server_status():

    try:
        hostname = subprocess.check_output(
            ["hostname"],
            text=True
        ).strip()
    except Exception:
        hostname = "Unknown"

    try:
        uptime = subprocess.check_output(
            ["uptime", "-p"],
            text=True
        ).strip()
    except Exception:
        uptime = "Unknown"

    try:
        disk = subprocess.check_output(
            ["df", "-h", "/"],
            text=True
        ).splitlines()[1].split()

        disk_used = disk[4]
    except Exception:
        disk_used = "Unknown"

    try:
        memory = subprocess.check_output(
            ["free", "-h"],
            text=True
        ).splitlines()[1].split()

        memory_used = memory[2]
        memory_total = memory[1]

        memory_text = f"{memory_used} / {memory_total}"

    except Exception:
        memory_text = "Unknown"

    return (
        "📊 *STATUS SERVER*\n\n"
        f"🖥 Hostname: `{hostname}`\n"
        f"⏱ Uptime: `{uptime}`\n"
        f"💾 Disk: `{disk_used}`\n"
        f"🧠 RAM: `{memory_text}`"
    )


# ============================================================
# SERVICE CHECK
# ============================================================

def service_status(service):

    try:
        result = subprocess.run(
            ["systemctl", "is-active", service],
            capture_output=True,
            text=True,
            timeout=10
        )

        status = result.stdout.strip()

        if status == "active":
            return "🟢 RUNNING"

        return "🔴 OFF"

    except Exception:
        return "⚪ UNKNOWN"


# ============================================================
# RESTART SERVICE
# ============================================================

def restart_service(service):

    try:
        result = subprocess.run(
            ["systemctl", "restart", service],
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode == 0:
            return True

        print(result.stderr)

    except Exception as e:
        print(f"Gagal restart {service}: {e}")

    return False


# ============================================================
# VPS MENU
# ============================================================

def get_vps_menu():

    menu_path = "/usr/bin/menu"

    if not os.path.isfile(menu_path):
        return (
            "⚠️ *Menu VPS tidak ditemukan.*\n\n"
            "File `/usr/bin/menu` belum tersedia."
        )

    return (
        "🖥 *MENU VPS*\n\n"
        "Menu `/usr/bin/menu` tersedia pada VPS.\n\n"
        "Kontrol VPS dari Telegram akan kita hubungkan "
        "langsung ke fungsi Ayah Alma."
    )


# ============================================================
# PLACEHOLDER INFORMATION
# ============================================================

def account_type_text(account_type):

    names = {
        "vmess": "🔵 VMess",
        "vless": "🟢 VLESS",
        "trojan": "🟠 Trojan",
        "ssh": "🔐 SSH"
    }

    return names.get(account_type, account_type)


def account_type_page(account_type):

    name = account_type_text(account_type)

    return (
        f"{name}\n\n"
        "Fungsi pengelolaan akun tersedia di Admin Panel.\n\n"
        "Generator akun akan dihubungkan ke script "
        "Ayah Alma yang tersedia pada VPS."
    )


# ============================================================
# /START
# ============================================================

def handle_start(chat_id):

    if is_admin(chat_id):
        text = (
            "🤖 *AYAH ALMA BOT*\n\n"
            "Selamat datang, Administrator.\n"
            "Akses Admin Panel tersedia."
        )
    else:
        text = (
            "🤖 *AYAH ALMA BOT*\n\n"
            "Selamat datang.\n"
            "Silakan pilih menu di bawah."
        )

    send_message(
        chat_id,
        text,
        main_menu(chat_id)
    )


# ============================================================
# /ADMIN
# ============================================================

def handle_admin(chat_id):

    if not is_admin(chat_id):
        send_message(
            chat_id,
            "⛔ *Akses ditolak.*\n\n"
            "Menu ini hanya untuk administrator."
        )
        return

    send_message(
        chat_id,
        "🔐 *ADMIN PANEL*\n\n"
        "Administrator memiliki akses penuh "
        "ke fungsi bot.",
        admin_menu()
    )


# ============================================================
# CALLBACK HANDLER
# ============================================================

def handle_callback(update):

    callback = update["callback_query"]

    callback_id = callback["id"]

    message = callback.get("message", {})

    chat = message.get("chat", {})

    chat_id = chat.get("id")

    message_id = message.get("message_id")

    data = callback.get("data", "")

    answer_callback(callback_id)

    # --------------------------------------------------------
    # PUBLIC
    # --------------------------------------------------------

    if data == "produk":

        text = (
            "📦 *DAFTAR PRODUK*\n\n"
            "🌐 *VPN / Xray*\n"
            "• VMess\n"
            "• VLESS\n"
            "• Trojan\n"
            "• GRPC / WS\n\n"
            "🔐 *SSH*\n"
            "• SSH Account\n"
            "• SSH WebSocket\n\n"
            "Untuk pembelian, silakan hubungi admin."
        )

        edit_message(
            chat_id,
            message_id,
            text,
            main_menu(chat_id)
        )

    elif data == "cara_order":

        text = (
            "💳 *CARA ORDER*\n\n"
            "1. Pilih produk.\n"
            "2. Hubungi admin.\n"
            "3. Lakukan pembayaran.\n"
            "4. Kirim bukti pembayaran jika diperlukan.\n"
            "5. Akun dibuat setelah pembayaran dikonfirmasi."
        )

        edit_message(
            chat_id,
            message_id,
            text,
            main_menu(chat_id)
        )

    elif data == "tentang":

        text = (
            "ℹ️ *AYAH ALMA BOT*\n\n"
            "Bot resmi untuk membantu pengelolaan "
            "layanan Ayah Alma.\n\n"
            "Versi: Universal"
        )

        edit_message(
            chat_id,
            message_id,
            text,
            main_menu(chat_id)
        )

    # --------------------------------------------------------
    # ADMIN
    # --------------------------------------------------------

    elif data == "admin":

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses admin ditolak.")
            return

        edit_message(
            chat_id,
            message_id,
            "🔐 *ADMIN PANEL*\n\n"
            "Administrator memiliki akses penuh "
            "ke fungsi bot.",
            admin_menu()
        )

    elif data == "status_server":

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        xray = service_status("xray")
        ssh = service_status("ssh")
        dropbear = service_status("dropbear")
        nginx = service_status("nginx")

        text = (
            get_server_status()
            + "\n\n"
            + "📡 *SERVICE*\n\n"
            + f"Xray: {xray}\n"
            + f"SSH: {ssh}\n"
            + f"Dropbear: {dropbear}\n"
            + f"Nginx: {nginx}"
        )

        edit_message(
            chat_id,
            message_id,
            text,
            admin_menu()
        )

    elif data == "kelola_akun":

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        edit_message(
            chat_id,
            message_id,
            "👥 *KELOLA AKUN*\n\n"
            "Pilih jenis akun:",
            account_menu()
        )

    elif data == "akun_vmess":

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        edit_message(
            chat_id,
            message_id,
            account_type_page("vmess"),
            account_menu()
        )

    elif data == "akun_vless":

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        edit_message(
            chat_id,
            message_id,
            account_type_page("vless"),
            account_menu()
        )

    elif data == "akun_trojan":

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        edit_message(
            chat_id,
            message_id,
            account_type_page("trojan"),
            account_menu()
        )

    elif data == "akun_ssh":

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        edit_message(
            chat_id,
            message_id,
            account_type_page("ssh"),
            account_menu()
        )

    elif data == "daftar_akun":

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        edit_message(
            chat_id,
            message_id,
            "📋 *DAFTAR AKUN*\n\n"
            "Daftar akun akan diambil langsung "
            "dari database/script Ayah Alma.",
            account_menu()
        )

    elif data == "buat_akun":

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        edit_message(
            chat_id,
            message_id,
            "➕ *BUAT AKUN*\n\n"
            "Pilih jenis akun terlebih dahulu.\n\n"
            "Setelah script generator Ayah Alma "
            "teridentifikasi, proses pembuatan akun "
            "akan dihubungkan langsung.",
            account_menu()
        )

    elif data == "hapus_akun":

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        edit_message(
            chat_id,
            message_id,
            "🗑 *HAPUS AKUN*\n\n"
            "Fungsi penghapusan akan menggunakan "
            "script akun Ayah Alma yang sebenarnya.",
            account_menu()
        )

    elif data == "renew_akun":

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        edit_message(
            chat_id,
            message_id,
            "🔄 *RENEW AKUN*\n\n"
            "Fungsi renew akan menggunakan database "
            "dan script akun Ayah Alma.",
            account_menu()
        )

    # --------------------------------------------------------
    # PRODUCTS
    # --------------------------------------------------------

    elif data == "admin_produk":

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        edit_message(
            chat_id,
            message_id,
            "📦 *KELOLA PRODUK*\n\n"
            "Pilih produk:",
            product_menu()
        )

    elif data in (
        "produk_vmess",
        "produk_vless",
        "produk_trojan",
        "produk_ssh"
    ):

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        product = data.replace("produk_", "").upper()

        edit_message(
            chat_id,
            message_id,
            f"📦 *PRODUK {product}*\n\n"
            "Pengaturan harga dan paket akan "
            "dihubungkan ke sistem produk Ayah Alma.",
            product_menu()
        )

    # --------------------------------------------------------
    # ORDERS
    # --------------------------------------------------------

    elif data == "pesanan":

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        edit_message(
            chat_id,
            message_id,
            "🧾 *PESANAN*\n\n"
            "Menu pengelolaan pesanan siap digunakan.\n\n"
            "Data pesanan akan dihubungkan ke database "
            "panel Faysal/Ayah Alma.",
            admin_menu()
        )

    # --------------------------------------------------------
    # PAYMENT
    # --------------------------------------------------------

    elif data == "pembayaran":

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        edit_message(
            chat_id,
            message_id,
            "💰 *PEMBAYARAN*\n\n"
            "Menu pembayaran admin.\n\n"
            "Konfirmasi pembayaran dan otomatisasi "
            "pembuatan akun akan dihubungkan kemudian.",
            admin_menu()
        )

    # --------------------------------------------------------
    # BOT SETTINGS
    # --------------------------------------------------------

    elif data == "pengaturan_bot":

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        edit_message(
            chat_id,
            message_id,
            "⚙️ *PENGATURAN BOT*\n\n"
            f"Config: `{CONFIG_FILE}`\n\n"
            f"Admin Chat ID: `{ADMIN_CHAT_ID}`\n"
            "Bot Token: terkonfigurasi\n\n"
            "Pengaturan lanjutan akan ditambahkan "
            "ke menu ini.",
            admin_menu()
        )

    # --------------------------------------------------------
    # VPS
    # --------------------------------------------------------

    elif data == "menu_vps":

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        edit_message(
            chat_id,
            message_id,
            get_vps_menu(),
            admin_menu()
        )

    # --------------------------------------------------------
    # RESTART XRAY
    # --------------------------------------------------------

    elif data == "restart_xray":

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        if restart_service("xray"):

            text = (
                "✅ *XRAY BERHASIL DIRESTART*\n\n"
                f"Status: {service_status('xray')}"
            )

        else:

            text = "❌ *Gagal melakukan restart Xray.*"

        edit_message(
            chat_id,
            message_id,
            text,
            admin_menu()
        )

    # --------------------------------------------------------
    # RESTART SSH
    # --------------------------------------------------------

    elif data == "restart_ssh":

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        if restart_service("ssh"):

            text = (
                "✅ *SSH BERHASIL DIRESTART*\n\n"
                f"Status: {service_status('ssh')}"
            )

        else:

            text = "❌ *Gagal melakukan restart SSH.*"

        edit_message(
            chat_id,
            message_id,
            text,
            admin_menu()
        )

    # --------------------------------------------------------
    # BACK
    # --------------------------------------------------------

    elif data == "back":

        handle_start(chat_id)


# ============================================================
# UPDATE HANDLER
# ============================================================

def process_update(update):

    if "message" in update:

        message = update["message"]

        chat = message.get("chat", {})

        chat_id = chat.get("id")

        text = message.get("text", "").strip()

        if not chat_id:
            return

        print(
            f"[MESSAGE] chat_id={chat_id} text={text}"
        )

        if text.startswith("/start"):

            handle_start(chat_id)

        elif text.startswith("/admin"):

            handle_admin(chat_id)

        elif text.startswith("/status"):

            if not is_admin(chat_id):

                send_message(
                    chat_id,
                    "⛔ Perintah ini hanya untuk admin."
                )

            else:

                send_message(
                    chat_id,
                    get_server_status(),
                    admin_menu()
                )

        elif text.startswith("/id"):

            send_message(
                chat_id,
                f"🆔 Chat ID kamu:\n`{chat_id}`"
            )

        elif text.startswith("/help"):

            send_message(
                chat_id,
                "🤖 *BANTUAN*\n\n"
                "/start - Menu utama\n"
                "/id - Melihat Chat ID\n"
                "/status - Status server\n"
                "/help - Bantuan\n"
                "/admin - Admin Panel"
            )

    elif "callback_query" in update:

        try:

            handle_callback(update)

        except Exception as e:

            print(
                f"Callback error: {e}"
            )


# ============================================================
# MAIN LOOP
# ============================================================

def main():

    print("======================================")
    print(" AYAH ALMA TELEGRAM BOT")
    print("======================================")
    print("Bot sedang berjalan...")

    offset = None

    while True:

        try:

            params = {
                "timeout": 30
            }

            if offset is not None:
                params["offset"] = offset

            response = requests.get(
                API_URL + "getUpdates",
                params=params,
                timeout=40
            )

            result = response.json()

            if not result.get("ok"):

                print(
                    f"Telegram API error: {result}"
                )

                time.sleep(5)

                continue

            updates = result.get(
                "result",
                []
            )

            for update in updates:

                offset = update["update_id"] + 1

                process_update(update)

        except KeyboardInterrupt:

            print("\nBot dihentikan.")

            break

        except Exception as e:

            print(
                f"Main loop error: {e}"
            )

            time.sleep(5)


# ============================================================
# START
# ============================================================

if __name__ == "__main__":
    main()
