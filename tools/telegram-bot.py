#!/usr/bin/env python3

import os
import time
import subprocess
import requests

# ============================================================
# AYAH ALMA TELEGRAM BOT
# Universal Telegram Bot
# Token dibaca dari:
# /etc/ayah-alma/telegram.conf
#
# Format:
# BOT_TOKEN="TOKEN_BOT"
# ADMIN_CHAT_ID="123456789"
# ============================================================

CONFIG_FILE = "/etc/ayah-alma/telegram.conf"


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
    print()
    print(f"Buat file:")
    print(f"  {CONFIG_FILE}")
    print()
    print('Contoh:')
    print('BOT_TOKEN="TOKEN_BOT_MILIKMU"')
    print('ADMIN_CHAT_ID="123456789"')
    raise SystemExit(1)


API_URL = f"https://api.telegram.org/bot{TOKEN}/"


# ============================================================
# TELEGRAM API
# ============================================================

def telegram_request(method, data=None, timeout=35):
    url = API_URL + method

    try:
        response = requests.post(
            url,
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

def main_menu():

    return {
        "inline_keyboard": [

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
                    "text": "⬅️ Kembali",
                    "callback_data": "back"
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
            "File `/usr/bin/menu` belum tersedia pada VPS ini."
        )

    return (
        "🖥 *MENU VPS*\n\n"
        "Menu VPS `/usr/bin/menu` tersedia.\n\n"
        "Untuk keamanan, bot tidak menjalankan menu "
        "terminal interaktif secara otomatis dari Telegram.\n\n"
        "Fungsi Telegram dapat kita hubungkan langsung "
        "ke script akun yang tersedia pada installer."
    )


# ============================================================
# /START
# ============================================================

def handle_start(chat_id):

    text = (
        "🤖 *AYAH ALMA BOT*\n\n"
        "Selamat datang.\n"
        "Silakan pilih menu di bawah."
    )

    send_message(
        chat_id,
        text,
        main_menu()
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
        "Pilih fungsi server:",
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
    # PUBLIC MENU
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
            main_menu()
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
            main_menu()
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
            main_menu()
        )

    # --------------------------------------------------------
    # ADMIN MENU
    # --------------------------------------------------------

    elif data == "admin":

        if not is_admin(chat_id):
            send_message(
                chat_id,
                "⛔ Akses admin ditolak."
            )
            return

        edit_message(
            chat_id,
            message_id,
            "🔐 *ADMIN PANEL*\n\nPilih fungsi:",
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

    elif data == "back":

        edit_message(
            chat_id,
            message_id,
            "🤖 *AYAH ALMA BOT*\n\n"
            "Silakan pilih menu:",
            main_menu()
        )


# ============================================================
# UPDATE HANDLER
# ============================================================

def process_update(update):

    # --------------------------------------------------------
    # MESSAGE
    # --------------------------------------------------------

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
                "/help - Bantuan\n"
                "/admin - Admin Panel"
            )

    # --------------------------------------------------------
    # CALLBACK
    # --------------------------------------------------------

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
