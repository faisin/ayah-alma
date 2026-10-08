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
