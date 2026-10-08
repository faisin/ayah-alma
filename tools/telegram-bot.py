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
                },
                {
                    "text": "📡 Service",
                    "callback_data": "service_menu"
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
                },
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
                },
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
# SERVICE MENU
# ============================================================

def service_menu():
    return {
        "inline_keyboard": [
            [
                {
                    "text": "📡 Status Semua Service",
                    "callback_data": "status_services"
                }
            ],
            [
                {
                    "text": "🔵 Xray",
                    "callback_data": "service_xray"
                },
                {
                    "text": "🔐 SSH",
                    "callback_data": "service_ssh"
                }
            ],
            [
                {
                    "text": "🟢 Dropbear",
                    "callback_data": "service_dropbear"
                },
                {
                    "text": "🌐 Nginx",
                    "callback_data": "service_nginx"
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

def command_output(command, default="Unknown"):
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=10
        )

        if result.returncode == 0:
            output = result.stdout.strip()

            if output:
                return output

    except Exception:
        pass

    return default


def get_server_status():
    hostname = command_output(
        ["hostname"],
        "Unknown"
    )

    uptime = command_output(
        ["uptime", "-p"],
        "Unknown"
    )

    disk = command_output(
        ["df", "-h", "/"],
        "Unknown"
    )

    disk_used = "Unknown"

    try:
        lines = disk.splitlines()

        if len(lines) > 1:
            parts = lines[1].split()

            if len(parts) >= 5:
                disk_used = parts[4]

    except Exception:
        pass

    memory = command_output(
        ["free", "-h"],
        "Unknown"
    )

    memory_text = "Unknown"

    try:
        lines = memory.splitlines()

        if len(lines) > 1:
            parts = lines[1].split()

            if len(parts) >= 3:
                memory_text = f"{parts[2]} / {parts[1]}"

    except Exception:
        pass

    load = command_output(
        ["cat", "/proc/loadavg"],
        "Unknown"
    )

    load_text = load.split()[0] if load != "Unknown" else "Unknown"

    return (
        "📊 *STATUS SERVER*\n\n"
        f"🖥 Hostname: `{hostname}`\n"
        f"⏱ Uptime: `{uptime}`\n"
        f"💾 Disk: `{disk_used}`\n"
        f"🧠 RAM: `{memory_text}`\n"
        f"⚡ Load: `{load_text}`"
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

        if status == "inactive":
            return "🔴 OFF"

        if status == "failed":
            return "🔴 FAILED"

        return f"⚪ {status.upper()}"

    except Exception:
        return "⚪ UNKNOWN"


def service_enabled(service):
    try:
        result = subprocess.run(
            ["systemctl", "is-enabled", service],
            capture_output=True,
            text=True,
            timeout=10
        )

        status = result.stdout.strip()

        if status == "enabled":
            return "AUTO"

        if status == "disabled":
            return "MANUAL"

        return status.upper()

    except Exception:
        return "UNKNOWN"


def service_detail(service):
    status = service_status(service)
    enabled = service_enabled(service)

    return (
        f"📡 *SERVICE: {service.upper()}*\n\n"
        f"Status: {status}\n"
        f"Boot: `{enabled}`"
    )


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
# SERVICE STATUS PAGE
# ============================================================

def get_services_status():
    services = [
        ("Xray", "xray"),
        ("SSH", "ssh"),
        ("Dropbear", "dropbear"),
        ("Nginx", "nginx"),
        ("Telegram Bot", "telegram-bot")
    ]

    lines = ["📡 *STATUS SERVICE*\n"]

    for name, service in services:
        lines.append(
            f"{name}: {service_status(service)}"
        )

    return "\n".join(lines)


# ============================================================
# VPS MENU
# ============================================================

def get_vps_menu():
    menu_path = "/usr/bin/menu"

    if not os.path.isfile(menu_path):
        return (
            "⚠️ *MENU VPS TIDAK DITEMUKAN*\n\n"
            "File `/usr/bin/menu` belum tersedia."
        )

    return (
        "🖥 *MENU VPS*\n\n"
        "File `/usr/bin/menu` tersedia.\n\n"
        "Kontrol Ayah Alma akan dihubungkan "
        "langsung ke fungsi yang sebenarnya."
    )


# ============================================================
# ACCOUNT INFORMATION
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
        "Menu jenis akun siap digunakan.\n\n"
        "Generator akun akan dihubungkan "
        "ke script Ayah Alma yang sebenarnya."
    )


# ============================================================
# START
# ============================================================

def handle_start(chat_id):
    if is_admin(chat_id):
        text = (
            "🤖 *AYAH ALMA BOT*\n\n"
            "Selamat datang, Administrator.\n\n"
            "🔐 Admin Panel tersedia."
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
# ADMIN
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
        "Semua fungsi administrasi bot tersedia "
        "dari menu ini.",
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

    if not chat_id:
        return

    # ========================================================
    # PUBLIC
    # ========================================================

    if data == "produk":

        text = (
            "📦 *DAFTAR PRODUK*\n\n"
            "🌐 *VPN / XRAY*\n"
            "• VMess\n"
            "• VLESS\n"
            "• Trojan\n"
            "• WebSocket\n"
            "• gRPC\n\n"
            "🔐 *SSH*\n"
            "• SSH Account\n"
            "• SSH WebSocket"
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
            "2. Pilih paket.\n"
            "3. Lakukan pembayaran.\n"
            "4. Kirim bukti pembayaran jika diperlukan.\n"
            "5. Pembayaran dikonfirmasi.\n"
            "6. Akun dibuat."
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
            "Bot untuk layanan Ayah Alma.\n\n"
            "Sistem akun, produk, pesanan dan "
            "pembayaran akan diintegrasikan "
            "secara bertahap."
        )

        edit_message(
            chat_id,
            message_id,
            text,
            main_menu(chat_id)
        )

    # ========================================================
    # ADMIN PANEL
    # ========================================================

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
            "🔐 *ADMIN PANEL*\n\n"
            "Pilih fungsi administrasi:",
            admin_menu()
        )

    # ========================================================
    # SERVER STATUS
    # ========================================================

    elif data == "status_server":

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        text = (
            get_server_status()
            + "\n\n"
            + get_services_status()
        )

        edit_message(
            chat_id,
            message_id,
            text,
            admin_menu()
        )

    # ========================================================
    # SERVICE MENU
    # ========================================================

    elif data == "service_menu":

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        edit_message(
            chat_id,
            message_id,
            "📡 *SERVICE SERVER*\n\n"
            "Pilih service:",
            service_menu()
        )

    elif data == "status_services":

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        edit_message(
            chat_id,
            message_id,
            get_services_status(),
            service_menu()
        )

    elif data in (
        "service_xray",
        "service_ssh",
        "service_dropbear",
        "service_nginx"
    ):

        if not is_admin(chat_id):
            send_message(chat_id, "⛔ Akses ditolak.")
            return

        service = data.replace(
            "service_",
            ""
        )

        edit_message(
            chat_id,

                if reply_markup is not None:
        data["reply_markup"] = reply_markup

    requests.post(
        f"{API_URL}/editMessageText",
        json=data,
        timeout=15
    )
