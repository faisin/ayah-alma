#!/usr/bin/env python3

import os
import time
import subprocess
from pathlib import Path
import requests


CONFIG_FILE = "/etc/ayah-alma/config/telegram.conf"


# ============================================================
# CONFIG
# ============================================================

def load_config():
    config = {}

    if not os.path.isfile(CONFIG_FILE):
        return config

    try:
        with open(CONFIG_FILE, "r", encoding="utf-8") as file:
            for line in file:
                line = line.strip()

                if not line:
                    continue

                if line.startswith("#"):
                    continue

                if "=" not in line:
                    continue

                key, value = line.split("=", 1)

                key = key.strip()
                value = value.strip()

                if (
                    len(value) >= 2
                    and value[0] == '"'
                    and value[-1] == '"'
                ):
                    value = value[1:-1]

                if (
                    len(value) >= 2
                    and value[0] == "'"
                    and value[-1] == "'"
                ):
                    value = value[1:-1]

                config[key] = value

    except Exception as error:
        print(f"Config error: {error}")

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

        response.raise_for_status()

        result = response.json()

        if not result.get("ok"):
            print(f"Telegram API error: {result}")

        return result

    except Exception as error:
        print(f"Telegram connection error: {error}")
        return None


def send_message(chat_id, text, reply_markup=None):
    data = {
        "chat_id": chat_id,
        "text": text,
        "parse_mode": "Markdown"
    }

    if reply_markup is not None:
        data["reply_markup"] = reply_markup

    return telegram_request("sendMessage", data)


def edit_message(chat_id, message_id, text, reply_markup=None):
    data = {
        "chat_id": chat_id,
        "message_id": message_id,
        "text": text,
        "parse_mode": "Markdown"
    }

    if reply_markup is not None:
        data["reply_markup"] = reply_markup

    return telegram_request("editMessageText", data)


def answer_callback(callback_id):
    return telegram_request(
        "answerCallbackQuery",
        {
            "callback_query_id": callback_id
        }
    )


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
        keyboard.append(
            [
                {
                    "text": "🔐 ADMIN PANEL",
                    "callback_data": "admin"
                }
            ]
        )

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
                    "text": "⬅️ Kembali",
                    "callback_data": "back"
                }
            ]
        ]
    }


# ============================================================
# COMMAND
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


# ============================================================
# SERVER STATUS
# ============================================================

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

    if load != "Unknown" and load.split():
        load_text = load.split()[0]
    else:
        load_text = "Unknown"

    return (
        "📊 *STATUS SERVER*\n\n"
        f"🖥 Hostname: `{hostname}`\n"
        f"⏱ Uptime: `{uptime}`\n"
        f"💾 Disk: `{disk_used}`\n"
        f"🧠 RAM: `{memory_text}`\n"
        f"⚡ Load: `{load_text}`"
    )


# ============================================================
# SERVICE
# ============================================================

def service_state(service):
    status = command_output(
        ["systemctl", "is-active", service],
        "unknown"
    )

    if status == "active":
        return "🟢 ONLINE"

    if status == "inactive":
        return "🔴 OFF"

    if status == "failed":
        return "🔴 FAILED"

    if status == "unknown":
        return "⚪ UNKNOWN"

    return f"⚪ {status.upper()}"


def get_services_status():
    return (
        "📡 *STATUS SERVICE*\n\n"
        f"🔵 Xray: {service_state('xray')}\n"
        f"🔐 SSH: {service_state('ssh')}\n"
        f"🟢 Dropbear: {service_state('dropbear')}\n"
        f"🌐 Nginx: {service_state('nginx')}"
    )


def get_service_detail(service):
    status = command_output(
        ["systemctl", "is-active", service],
        "unknown"
    )

    enabled = command_output(
        ["systemctl", "is-enabled", service],
        "unknown"
    )

    names = {
        "xray": "🔵 Xray",
        "ssh": "🔐 SSH",
        "dropbear": "🟢 Dropbear",
        "nginx": "🌐 Nginx"
    }

    name = names.get(service, service)

    return (
        f"📡 *{name}*\n\n"
        f"Status: `{status}`\n"
        f"Autostart: `{enabled}`"
    )


def restart_service(service):
    try:
        result = subprocess.run(
            ["systemctl", "restart", service],
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode != 0:
            error = result.stderr.strip()

            if error:
                return (
                    f"❌ Gagal restart `{service}`.\n\n"
                    f"`{error[:1000]}`"
                )

            return f"❌ Gagal restart `{service}`."

        time.sleep(1)

        status = command_output(
            ["systemctl", "is-active", service],
            "unknown"
        )

        if status == "active":
            return f"✅ `{service}` berhasil direstart."

        return (
            f"⚠️ `{service}` sudah direstart.\n"
            f"Status: `{status}`"
        )

    except Exception as error:
        return f"❌ Error: `{error}`"


# ============================================================
# VPS MENU
# ============================================================

def vps_menu():
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
                    "text": "📡 Status Service",
                    "callback_data": "status_services"
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
                    "text": "⬅️ Admin Panel",
                    "callback_data": "admin"
                }
            ]
        ]
    }


# ============================================================
# TEXT
# ============================================================

def product_text(product):
    names = {
        "vmess": "🔵 VMess",
        "vless": "🟢 VLESS",
        "trojan": "🟠 Trojan",
        "ssh": "🔐 SSH"
    }

    name = names.get(product, product.upper())

    return (
        f"{name}\n\n"
        "Layanan Ayah Alma.\n"
        "Silakan hubungi admin untuk informasi "
        "harga dan pemesanan."
    )


def account_text(account_type):
    names = {
        "vmess": "🔵 VMess",
        "vless": "🟢 VLESS",
        "trojan": "🟠 Trojan",
        "ssh": "🔐 SSH"
    }

    name = names.get(account_type, account_type.upper())

    return (
        f"{name}\n\n"
        "Menu pengelolaan akun."
    )


# ============================================================
# START
# ============================================================

def handle_start(chat_id):
    send_message(
        chat_id,
        "👋 *SELAMAT DATANG DI AYAH ALMA*\n\n"
        "Silakan pilih menu:",
        main_menu(chat_id)
    )


def handle_admin(chat_id):
    if not is_admin(chat_id):
        send_message(
            chat_id,
            "⛔ Akses Admin ditolak."
        )
        return

    send_message(
        chat_id,
        "🔐 *ADMIN PANEL*\n\n"
        "Pilih menu:",
        admin_menu()
    )


# ============================================================
# ACCOUNT INTEGRATION
# ============================================================

ACCOUNT_SCRIPTS = {
    "vmess": {
        "create": "/etc/ayah-alma/xray/add-vmess.sh",
        "delete": "/etc/ayah-alma/xray/del-vmess.sh",
        "renew": "/etc/ayah-alma/xray/renew-vmess.sh",
        "db": "/etc/xray/vmess.db",
    },
    "vless": {
        "create": "/etc/ayah-alma/xray/add-vless.sh",
        "delete": "/etc/ayah-alma/xray/del-vless.sh",
        "renew": "/etc/ayah-alma/xray/renew-vless.sh",
        "db": "/etc/xray/vless.db",
    },
    "trojan": {
        "create": "/etc/ayah-alma/xray/add-trojan.sh",
        "delete": "/etc/ayah-alma/xray/del-trojan.sh",
        "renew": "/etc/ayah-alma/xray/renew-trojan.sh",
        "db": "/etc/xray/trojan.db",
    },
    "ssh": {
        "create": "/etc/ayah-alma/ssh/addssh.sh",
        "delete": "/etc/ayah-alma/ssh/del-ssh.sh",
        "renew": "/etc/ayah-alma/ssh/renew-ssh.sh",
        "db": "/root/accounts",
    },
}

ACCOUNT_NAMES = {
    "vmess": "🔵 VMess",
    "vless": "🟢 VLESS",
    "trojan": "🟠 Trojan",
    "ssh": "🔐 SSH",
}

# chat_id -> data percakapan sementara.
# Data hanya hidup selama proses bot berjalan dan tidak menyimpan password.
PENDING_ACCOUNT = {}


def account_type_menu(action):
    labels = {
        "create": "➕ BUAT AKUN",
        "delete": "🗑 HAPUS AKUN",
        "renew": "🔄 RENEW AKUN",
    }
    return {
        "inline_keyboard": [
            [
                {"text": "🔵 VMess", "callback_data": f"account_{action}_vmess"},
                {"text": "🟢 VLESS", "callback_data": f"account_{action}_vless"},
            ],
            [
                {"text": "🟠 Trojan", "callback_data": f"account_{action}_trojan"},
                {"text": "🔐 SSH", "callback_data": f"account_{action}_ssh"},
            ],
            [{"text": "⬅️ Kelola Akun", "callback_data": "kelola_akun"}],
        ]
    }


def account_action_menu(account_type):
    name = ACCOUNT_NAMES.get(account_type, account_type.upper())
    return {
        "inline_keyboard": [
            [{"text": "➕ Buat", "callback_data": f"account_create_{account_type}"}],
            [{"text": "🗑 Hapus", "callback_data": f"account_delete_{account_type}"}],
            [{"text": "🔄 Renew", "callback_data": f"account_renew_{account_type}"}],
            [{"text": "⬅️ Pilih Jenis", "callback_data": "kelola_akun"}],
        ]
    }


def account_prompt_menu(account_type, action):
    name = ACCOUNT_NAMES.get(account_type, account_type.upper())
    labels = {
        "create": "➕ BUAT AKUN",
        "delete": "🗑 HAPUS AKUN",
        "renew": "🔄 RENEW AKUN",
    }
    if action == "create":
        if account_type == "ssh":
            text = (
                f"{labels[action]} {name}\n\n"
                "Kirim data dalam 4 baris:\n"
                "`username`\n`password`\n`masa aktif (hari)`\n`limit device`\n\n"
                "Contoh:\n`user01\\npass123\\n30\\n2`"
            )
        elif account_type == "vmess":
            text = (
                f"{labels[action]} {name}\n\n"
                "Kirim data dalam 3 baris:\n"
                "`username`\n`masa aktif (hari)`\n`limit device`\n\n"
                "Contoh:\n`user01\\n30\\n2`"
            )
        else:
            text = (
                f"{labels[action]} {name}\n\n"
                "Kirim data dalam 2 baris:\n"
                "`username`\n`masa aktif (hari)`\n\n"
                "Contoh:\n`user01\\n30`"
            )
    elif action == "delete":
        text = f"{labels[action]} {name}\n\nKirim `username` yang ingin dihapus."
    else:
        text = f"{labels[action]} {name}\n\nKirim data dalam 2 baris:\n`username`\n`tambahan hari`"
    return text


def run_account_script(account_type, action, input_text):
    info = ACCOUNT_SCRIPTS.get(account_type)
    if not info:
        return "❌ Jenis akun tidak dikenal."

    script = info.get(action)
    if not script or not os.path.isfile(script):
        return f"❌ Script tidak ditemukan:\n`{script}`"

    try:
        env = os.environ.copy()
        env["TERM"] = "xterm"

        result = subprocess.run(
            ["bash", script],
            input=input_text,
            capture_output=True,
            text=True,
            timeout=60,
            cwd="/root",
            env=env,
        )
        output = (result.stdout or "") + ("\n" + result.stderr if result.stderr else "")
        output = output.strip()
        # Hilangkan escape terminal dari `clear` agar Telegram tetap bersih.
        import re
        output = re.sub(r"\\x1b\\[[0-9;?]*[ -/]*[@-~]", "", output)
        if not output:
            output = "Selesai tanpa output."
        if result.returncode == 0:
            return "✅ *BERHASIL*\n\n" + output[-3800:]
        return "❌ *SCRIPT GAGAL*\n\n" + output[-3800:]
    except subprocess.TimeoutExpired:
        return "⏱️ Script melebihi batas waktu 60 detik dan dihentikan."
    except Exception as error:
        return f"❌ Error menjalankan script:\n`{error}`"


def list_accounts_text():
    sections = ["📋 *DAFTAR AKUN*"]

    for account_type in ("vmess", "vless", "trojan"):
        db = ACCOUNT_SCRIPTS[account_type]["db"]
        name = ACCOUNT_NAMES[account_type]
        lines = []
        try:
            if os.path.isfile(db):
                with open(db, "r", encoding="utf-8", errors="ignore") as file:
                    for line in file:
                        parts = line.split()
                        if parts:
                            user = parts[0]
                            exp = parts[1] if len(parts) > 1 else "-"
                            lines.append(f"• `{user}` — {exp}")
        except Exception as error:
            lines.append(f"• Error: `{error}`")
        sections.append(f"\n{name}")
        sections.extend(lines or ["• Tidak ada akun."])

    ssh_lines = []
    try:
        account_dir = ACCOUNT_SCRIPTS["ssh"]["db"]
        if os.path.isdir(account_dir):
            for filename in sorted(os.listdir(account_dir)):
                if filename.endswith(".txt"):
                    user = filename[:-4]
                    try:
                        content = Path(os.path.join(account_dir, filename)).read_text(
                            encoding="utf-8", errors="ignore"
                        )
                        exp = "-"
                        for line in content.splitlines():
                            if "Expired" in line and ":" in line:
                                exp = line.split(":", 1)[1].strip()
                                break
                        ssh_lines.append(f"• `{user}` — {exp}")
                    except Exception:
                        ssh_lines.append(f"• `{user}`")
    except Exception as error:
        ssh_lines.append(f"• Error: `{error}`")
    sections.append("\n🔐 SSH")
    sections.extend(ssh_lines or ["• Tidak ada akun."])

    return "\n".join(sections)[-3900:]


def begin_account_action(chat_id, account_type, action):
    PENDING_ACCOUNT[chat_id] = {
        "type": account_type,
        "action": action,
    }
    return account_prompt_menu(account_type, action)


def cancel_account_action(chat_id):
    PENDING_ACCOUNT.pop(chat_id, None)


def process_account_input(chat_id, text):
    pending = PENDING_ACCOUNT.get(chat_id)
    if not pending:
        return False

    if text.lower() in ("/cancel", "batal", "cancel"):
        cancel_account_action(chat_id)
        send_message(chat_id, "❌ Proses dibatalkan.", account_menu())
        return True

    account_type = pending["type"]
    action = pending["action"]
    values = [line.strip() for line in text.splitlines() if line.strip()]

    if action == "create":
        if account_type == "ssh":
            if len(values) != 4:
                send_message(chat_id, "❌ Format salah. Kirim tepat 4 baris: username, password, masa aktif, limit device.")
                return True
            username, password, days, limit = values
            if not username or not days.isdigit() or not limit.isdigit():
                send_message(chat_id, "❌ Data tidak valid. Masa aktif dan limit device harus angka.")
                return True
            script_input = f"1\n{username}\n{password}\n{days}\n{limit}\n"
        elif account_type == "vmess":
            if len(values) != 3:
                send_message(chat_id, "❌ Format salah. Kirim: username, masa aktif, limit device.")
                return True
            username, days, limit = values
            if not days.isdigit() or not limit.isdigit():
                send_message(chat_id, "❌ Masa aktif dan limit device harus angka.")
                return True
            script_input = f"{username}\n{days}\n{limit}\n"
        else:
            if len(values) != 2:
                send_message(chat_id, "❌ Format salah. Kirim: username dan masa aktif.")
                return True
            username, days = values
            if not days.isdigit():
                send_message(chat_id, "❌ Masa aktif harus angka.")
                return True
            script_input = f"{username}\n{days}\n"

    elif action == "delete":
        if len(values) != 1:
            send_message(chat_id, "❌ Kirim hanya username yang ingin dihapus.")
            return True
        script_input = f"{values[0]}\n"

    elif action == "renew":
        if len(values) != 2:
            send_message(chat_id, "❌ Format salah. Kirim username lalu tambahan hari.")
            return True
        username, days = values
        if not days.isdigit():
            send_message(chat_id, "❌ Tambahan hari harus angka.")
            return True
        script_input = f"{username}\n{days}\n"
    else:
        cancel_account_action(chat_id)
        return False

    # Hapus state sebelum menjalankan script supaya tidak mengulang input
    # jika proses script gagal.
    cancel_account_action(chat_id)
    send_message(chat_id, "⏳ Memproses akun...")
    result = run_account_script(account_type, action, script_input)
    send_message(chat_id, result, account_menu())
    return True


# ============================================================
# CALLBACK
# ============================================================

def handle_callback(
    chat_id,
    message_id,
    data,
    callback_id
):
    answer_callback(callback_id)

    admin_actions = (
        "admin",
        "status_server",
        "service_menu",
        "status_services",
        "service_xray",
        "service_ssh",
        "service_dropbear",
        "service_nginx",
        "kelola_akun",
        "akun_vmess",
        "akun_vless",
        "akun_trojan",
        "akun_ssh",
        "daftar_akun",
        "buat_akun",
        "hapus_akun",
        "renew_akun",
        "admin_produk",
        "pesanan",
        "pembayaran",
        "pengaturan_bot",
        "menu_vps",
        "restart_xray",
        "restart_ssh"
    )

    if data in admin_actions and not is_admin(chat_id):
        edit_message(
            chat_id,
            message_id,
            "⛔ *AKSES DITOLAK*"
        )
        return

    if data == "back":
        edit_message(
            chat_id,
            message_id,
            "👋 *MENU UTAMA*\n\n"
            "Silakan pilih menu:",
            main_menu(chat_id)
        )
        return

    if data == "produk":
        edit_message(
            chat_id,
            message_id,
            "🌐 *PRODUK / LAYANAN*\n\n"
            "Pilih layanan:",
            product_menu()
        )
        return

    if data == "cara_order":
        edit_message(
            chat_id,
            message_id,
            "💳 *CARA ORDER*\n\n"
            "1. Pilih produk.\n"
            "2. Hubungi admin.\n"
            "3. Lakukan pembayaran.\n"
            "4. Admin memproses pesanan.",
            main_menu(chat_id)
        )
        return

    if data == "tentang":
        edit_message(
            chat_id,
            message_id,
            "ℹ️ *TENTANG AYAH ALMA*\n\n"
            "Bot administrasi Ayah Alma "
            "untuk pengelolaan layanan dan VPS.",
            main_menu(chat_id)
        )
        return

    if data.startswith("produk_"):
        product = data.replace(
            "produk_",
            "",
            1
        )

        edit_message(
            chat_id,
            message_id,
            product_text(product),
            product_menu()
        )
        return

    if data == "admin":
        edit_message(
            chat_id,
            message_id,
            "🔐 *ADMIN PANEL*\n\n"
            "Pilih menu:",
            admin_menu()
        )
        return

    if data == "status_server":
        edit_message(
            chat_id,
            message_id,
            get_server_status(),
            admin_menu()
        )
        return

    if data == "service_menu":
        edit_message(
            chat_id,
            message_id,
            "📡 *SERVICE VPS*\n\n"
            "Pilih service:",
            service_menu()
        )
        return

    if data == "status_services":
        edit_message(
            chat_id,
            message_id,
            get_services_status(),
            service_menu()
        )
        return

    if data in (
        "service_xray",
        "service_ssh",
        "service_dropbear",
        "service_nginx"
    ):
        service = data.replace(
            "service_",
            "",
            1
        )

        edit_message(
            chat_id,
            message_id,
            get_service_detail(service),
            service_menu()
        )
        return

    if data == "kelola_akun":
        edit_message(
            chat_id,
            message_id,
            "👥 *KELOLA AKUN*\n\n"
            "Pilih jenis akun:",
            account_menu()
        )
        return

    if data in (
        "akun_vmess",
        "akun_vless",
        "akun_trojan",
        "akun_ssh"
    ):
        account_type = data.replace("akun_", "", 1)
        edit_message(
            chat_id,
            message_id,
            f"{ACCOUNT_NAMES[account_type]}\n\nPilih tindakan:",
            account_action_menu(account_type)
        )
        return

    if data == "daftar_akun":
        edit_message(
            chat_id,
            message_id,
            list_accounts_text(),
            account_menu()
        )
        return

    if data in ("buat_akun", "hapus_akun", "renew_akun"):
        action = {
            "buat_akun": "create",
            "hapus_akun": "delete",
            "renew_akun": "renew",
        }[data]
        edit_message(
            chat_id,
            message_id,
            {
                "create": "➕ *BUAT AKUN*\n\nPilih jenis akun:",
                "delete": "🗑 *HAPUS AKUN*\n\nPilih jenis akun:",
                "renew": "🔄 *RENEW AKUN*\n\nPilih jenis akun:",
            }[action],
            account_type_menu(action)
        )
        return

    if data.startswith("account_create_") or data.startswith("account_delete_") or data.startswith("account_renew_"):
        parts = data.split("_")
        action = parts[1]
        account_type = parts[2]
        if account_type not in ACCOUNT_SCRIPTS:
            edit_message(chat_id, message_id, "❌ Jenis akun tidak dikenal.", account_menu())
            return
        prompt = begin_account_action(chat_id, account_type, action)
        edit_message(chat_id, message_id, prompt, account_action_menu(account_type))
        return

    if data == "admin_produk":
        edit_message(
            chat_id,
            message_id,
            "📦 *PRODUK / LAYANAN ADMIN*\n\n"
            "Pilih produk:",
            product_menu()
        )
        return

    if data == "pesanan":
        edit_message(
            chat_id,
            message_id,
            "🧾 *PESANAN*\n\n"
            "Integrasi database pesanan belum "
            "dihubungkan.",
            admin_menu()
        )
        return

    if data == "pembayaran":
        edit_message(
            chat_id,
            message_id,
            "💰 *PEMBAYARAN*\n\n"
            "Integrasi pembayaran belum "
            "dihubungkan.",
            admin_menu()
        )
        return

    if data == "pengaturan_bot":
        edit_message(
            chat_id,
            message_id,
            "⚙️ *PENGATURAN BOT*\n\n"
            f"Config: `{CONFIG_FILE}`\n"
            f"Admin ID: `{ADMIN_CHAT_ID}`",
            admin_menu()
        )
        return

    if data == "menu_vps":
        edit_message(
            chat_id,
            message_id,
            "🖥 *MENU VPS*\n\n"
            "Pilih tindakan:",
            vps_menu()
        )
        return

    if data == "restart_xray":
        edit_message(
            chat_id,
            message_id,
            restart_service("xray"),
            admin_menu()
        )
        return

    if data == "restart_ssh":
        edit_message(
            chat_id,
            message_id,
            restart_service("ssh"),
            admin_menu()
        )
        return

    edit_message(
        chat_id,
        message_id,
        "❌ Menu tidak ditemukan.",
        main_menu(chat_id)
    )


# ============================================================
# UPDATE
# ============================================================

def process_update(update):
    try:
        message = update.get("message")

        if message:
            chat = message.get("chat", {})
            chat_id = chat.get("id")

            if chat_id is None:
                return

            text = message.get("text", "").strip()

            if chat_id in PENDING_ACCOUNT and text:
                if process_account_input(chat_id, text):
                    return

            if text == "/start":
                handle_start(chat_id)
                return

            if text == "/admin":
                handle_admin(chat_id)
                return

            if text == "/status":
                if not is_admin(chat_id):
                    send_message(
                        chat_id,
                        "⛔ Akses ditolak."
                    )
                    return

                send_message(
                    chat_id,
                    get_server_status(),
                    admin_menu()
                )
                return

            if text == "/id":
                send_message(
                    chat_id,
                    f"🆔 Chat ID: `{chat_id}`"
                )
                return

            if text == "/help":
                send_message(
                    chat_id,
                    "📖 *BANTUAN*\n\n"
                    "/start - Menu utama\n"
                    "/admin - Admin Panel\n"
                    "/status - Status server\n"
                    "/id - Lihat Chat ID\n"
                    "/help - Bantuan"
                )
                return

            send_message(
                chat_id,
                "Silakan pilih menu:",
                main_menu(chat_id)
            )

            return

        callback = update.get("callback_query")

        if callback:
            callback_id = callback.get("id")
            data = callback.get("data", "")

            callback_message = callback.get(
                "message",
                {}
            )

            chat = callback_message.get(
                "chat",
                {}
            )

            chat_id = chat.get("id")
            message_id = callback_message.get(
                "message_id"
            )

            if (
                callback_id
                and chat_id is not None
                and message_id is not None
            ):
                handle_callback(
                    chat_id,
                    message_id,
                    data,
                    callback_id
                )

    except Exception as error:
        print(f"Update error: {error}")


# ============================================================
# POLLING
# ============================================================

def get_updates(offset=None):
    data = {
        "timeout": 30
    }

    if offset is not None:
        data["offset"] = offset

    return telegram_request(
        "getUpdates",
        data,
        timeout=40
    )


def main():
    print("============================================")
    print(" AYAH ALMA TELEGRAM BOT")
    print("============================================")
    print("Bot started.")

    offset = None

    while True:
        try:
            result = get_updates(offset)

            if not result:
                time.sleep(3)
                continue

            if not result.get("ok"):
                time.sleep(5)
                continue

            updates = result.get(
                "result",
                []
            )

            for update in updates:
                update_id = update.get(
                    "update_id"
                )

                if update_id is not None:
                    offset = update_id + 1

                process_update(update)

        except KeyboardInterrupt:
            print("Bot stopped.")
            break

        except Exception as error:
            print(f"Main loop error: {error}")
            time.sleep(5)


# ============================================================
# START PROGRAM
# ============================================================

if __name__ == "__main__":
    main()
