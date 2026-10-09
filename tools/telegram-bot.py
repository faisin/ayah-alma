#!/usr/bin/env python3

import os
import time
import subprocess
import tempfile
import re
import json
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

def get_admin_ids():
    return {
        item.strip()
        for item in str(ADMIN_CHAT_ID).split(",")
        if item.strip()
    }


def is_admin(chat_id):
    return str(chat_id) in get_admin_ids()


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
                },
                {
                    "text": "📋 Daftar Akun",
                    "callback_data": "daftar_akun"
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
                    "text": "🎁 Reset Limit Trial",
                    "callback_data": "reset_trial"
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
                {"text": "🔵 VMess", "callback_data": "produk_vmess"},
                {"text": "🟢 VLESS", "callback_data": "produk_vless"}
            ],
            [
                {"text": "🟠 Trojan", "callback_data": "produk_trojan"},
                {"text": "🔐 SSH", "callback_data": "produk_ssh"}
            ],
            [
                {"text": "🎁 TRIAL VMess", "callback_data": "trial_vmess"},
                {"text": "⬅️ Kembali", "callback_data": "back"}
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
# TRIAL
# ============================================================

def trial_used(chat_id):
    """Cek apakah Telegram Chat ID sudah pernah berhasil memakai trial."""
    try:
        if not os.path.isfile(TRIAL_RECORD_FILE):
            return False

        target = str(chat_id)
        with open(TRIAL_RECORD_FILE, "r", encoding="utf-8", errors="ignore") as file:
            for line in file:
                value = line.strip().split("|", 1)[0]
                if value == target:
                    return True
    except Exception as error:
        print(f"Trial check error: {error}")

    return False


def mark_trial_used(chat_id, username):
    """Catat trial hanya setelah generator berhasil."""
    os.makedirs(os.path.dirname(TRIAL_RECORD_FILE), exist_ok=True)

    with open(TRIAL_RECORD_FILE, "a", encoding="utf-8") as file:
        file.write(f"{chat_id}|{username}|{int(time.time())}\n")


def process_trial_reset_input(admin_chat_id, text):
    """Validasi ID Telegram lalu minta konfirmasi sebelum reset limit trial."""
    target_id = text.strip()
    if target_id.lower() in ("batal", "cancel", "/cancel"):
        PENDING_TRIAL_RESET.pop(admin_chat_id, None)
        send_message(admin_chat_id, "❎ Reset trial dibatalkan.", admin_menu())
        return True

    if not target_id.isdigit() or len(target_id) > 20:
        send_message(admin_chat_id, "❌ ID Telegram tidak valid. Kirim angka ID Telegram, atau ketik `batal`.")
        return True

    PENDING_TRIAL_RESET.pop(admin_chat_id, None)
    PENDING_TRIAL_RESET[admin_chat_id] = target_id
    send_message(
        admin_chat_id,
        "⚠️ *KONFIRMASI RESET TRIAL*\n\n"
        f"ID Telegram: `{target_id}`\n"
        "Limit trial ID ini akan dihapus dari catatan bot. Akun yang sudah dibuat tidak dihapus.\n\n"
        "Lanjutkan?",
        {
            "inline_keyboard": [
                [{"text": "✅ Ya, Reset Limit", "callback_data": f"trial_reset_confirm_{target_id}"}],
                [{"text": "❎ Batal", "callback_data": "trial_reset_cancel"}],
            ]
        }
    )
    return True


def reset_trial_record(target_id):
    """Hapus catatan trial untuk satu Telegram ID; akun VMess tidak dihapus."""
    if not os.path.isfile(TRIAL_RECORD_FILE):
        return False

    with open(TRIAL_RECORD_FILE, "r", encoding="utf-8", errors="ignore") as file:
        lines = file.readlines()

    kept = []
    removed = False
    for line in lines:
        recorded_id = line.strip().split("|", 1)[0]
        if recorded_id == str(target_id):
            removed = True
        else:
            kept.append(line)

    if removed:
        temp_path = TRIAL_RECORD_FILE + ".tmp"
        with open(temp_path, "w", encoding="utf-8") as file:
            file.writelines(kept)
        os.replace(temp_path, TRIAL_RECORD_FILE)

    return removed


def trial_menu():
    return {
        "inline_keyboard": [
            [
                {
                    "text": "🎁 Ambil Trial VMess",
                    "callback_data": "trial_start"
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


def begin_trial(chat_id):
    if trial_used(chat_id):
        send_message(
            chat_id,
            "❌ *TRIAL SUDAH PERNAH DIGUNAKAN*\n\n"
            "Satu akun Telegram hanya mendapatkan trial satu kali.\n"
            "Trial tidak direset berdasarkan hari.\n\n"
            "Jika ingin menggunakan akun lagi, silakan pilih "
            "paket berbayar.",
            main_menu(chat_id)
        )
        return

    PENDING_TRIAL[chat_id] = {
        "stage": "username"
    }

    send_message(
        chat_id,
        "🎁 *TRIAL VMESS*\n\n"
        "Trial hanya dapat digunakan *1 kali untuk 1 ID Telegram*.\n\n"
        "Masukkan username trial:\n"
        "Gunakan huruf, angka, atau underscore.\n\n"
        "Ketik `batal` untuk membatalkan."
    )


def process_trial_input(chat_id, text):
    trial = PENDING_TRIAL.get(chat_id)
    if not trial:
        return False

    if text.lower() in ("batal", "cancel", "/cancel"):
        PENDING_TRIAL.pop(chat_id, None)
        send_message(chat_id, "❌ Trial dibatalkan.", main_menu(chat_id))
        return True

    if trial.get("stage") != "username":
        return False

    if not re.fullmatch(r"[A-Za-z0-9_]{1,32}", text):
        send_message(
            chat_id,
            "❌ Username tidak valid.\n"
            "Gunakan hanya huruf, angka, dan underscore."
        )
        return True

    if trial_used(chat_id):
        PENDING_TRIAL.pop(chat_id, None)
        send_message(
            chat_id,
            "❌ ID Telegram ini sudah pernah menggunakan trial.",
            main_menu(chat_id)
        )
        return True

    username = text
    PENDING_TRIAL.pop(chat_id, None)

    send_message(
        chat_id,
        "⏳ *Memproses Trial VMess...*\n\n"
        f"Username: `{username}`"
    )

    if not os.path.isfile(TRIAL_SCRIPT):
        send_message(
            chat_id,
            f"❌ Script trial tidak ditemukan:\n`{TRIAL_SCRIPT}`",
            main_menu(chat_id)
        )
        return True

    # trial-vmess.sh adalah generator trial Ayah Alma.
    # Input username dikirim sebagai input pertama.
    result = run_account_script(
        "trial_vmess",
        "create",
        f"{username}\n"
    )

    if result.startswith("✅"):
        try:
            mark_trial_used(chat_id, username)
        except Exception as error:
            # Jangan mengklaim trial berhasil sekali-seumur-hidup bila
            # pencatatan gagal.
            send_message(
                chat_id,
                "❌ Trial berhasil dibuat, tetapi pencatatan ID trial gagal. "
                f"Hubungi admin. Error: `{error}`",
                main_menu(chat_id)
            )
            return True

        send_message(
            chat_id,
            "🎁 *TRIAL BERHASIL*\n\n" + result[3:].lstrip(),
            main_menu(chat_id)
        )
    else:
        send_message(
            chat_id,
            result,
            main_menu(chat_id)
        )

    return True


# ============================================================
# PUBLIC ORDER / PRICE
# ============================================================

# Paket berbayar.
# VMess tersedia untuk 7 hari dan 30 hari.
# VMess 7 hari: 1 device Rp3.000, 2 device Rp5.000, 3 device Rp7.000.
# Paket 30 hari dan produk lain tetap menggunakan harga sebelumnya.
PRICE_TABLE = {
    "vmess": {
        7: {1: 3000, 2: 5000, 3: 7000},
        30: {1: 5000, 2: 7000, 3: 10000, 4: 15000},
    },
    "vless": {
        30: {1: 5000, 2: 7000, 3: 10000, 4: 15000},
    },
    "trojan": {
        30: {1: 5000, 2: 7000, 3: 10000, 4: 15000},
    },
    "ssh": {
        30: {1: 5000, 2: 7000, 3: 10000, 4: 15000},
    },
}

PRODUCT_NAMES = {
    "vmess": "🔵 VMess",
    "vless": "🟢 VLESS",
    "trojan": "🟠 Trojan",
    "ssh": "🔐 SSH",
}

# Pesanan disimpan di disk agar tidak hilang ketika service bot restart.
ORDERS_FILE = "/etc/ayah-alma/config/telegram-orders.json"

def load_orders():
    try:
        with open(ORDERS_FILE, "r", encoding="utf-8") as file:
            data = json.load(file)
        if isinstance(data, dict):
            return {int(key): value for key, value in data.items() if isinstance(value, dict)}
    except FileNotFoundError:
        pass
    except Exception as error:
        print(f"Orders load error: {error}")
    return {}

def save_orders():
    try:
        os.makedirs(os.path.dirname(ORDERS_FILE), exist_ok=True)
        temp_file = ORDERS_FILE + ".tmp"
        with open(temp_file, "w", encoding="utf-8") as file:
            json.dump({str(key): value for key, value in PENDING_ORDER.items()}, file, ensure_ascii=False, indent=2)
        os.chmod(temp_file, 0o600)
        os.replace(temp_file, ORDERS_FILE)
    except Exception as error:
        print(f"Orders save error: {error}")

PENDING_ORDER = load_orders()

# Trial disimpan permanen di VPS berdasarkan Telegram Chat ID.
# Satu Chat ID hanya boleh berhasil membuat trial satu kali.
TRIAL_RECORD_FILE = "/etc/ayah-alma/config/telegram-trial.db"
TRIAL_SCRIPT = "/etc/ayah-alma/xray/trial-vmess.sh"
PENDING_TRIAL = {}
PENDING_TRIAL_RESET = {}


def rupiah(value):
    return "Rp" + f"{int(value):,}".replace(",", ".")


def product_text(product):
    name = PRODUCT_NAMES.get(product, product.upper())
    durations = PRICE_TABLE.get(product, {})
    if not durations:
        return (
            f"{name}\n\n"
            "❌ Paket untuk produk ini belum tersedia.\n"
            "Silakan hubungi admin."
        )
    return (
        f"{name}\n\n"
        "Pilih masa aktif untuk mulai membuat pesanan:"
    )


def duration_menu(product):
    rows = []
    for days in sorted(PRICE_TABLE.get(product, {})):
        rows.append([{
            "text": f"📅 {days} Hari",
            "callback_data": f"order_days_{product}_{days}"
        }])
    rows.append([{
        "text": "⬅️ Produk",
        "callback_data": "produk"
    }])
    return {"inline_keyboard": rows}


def device_menu(product, days):
    prices = PRICE_TABLE.get(product, {}).get(days, {})
    rows = []
    for device in sorted(prices):
        rows.append([{
            "text": f"📱 {device} Device — {rupiah(prices[device])}",
            "callback_data": f"order_device_{product}_{days}_{device}"
        }])
    rows.append([{
        "text": "⬅️ Masa Aktif",
        "callback_data": f"order_product_{product}"
    }])
    return {"inline_keyboard": rows}


def order_summary(order):
    product = order["product"]
    name = PRODUCT_NAMES[product]
    lines = [
        "🧾 *RINGKASAN PESANAN*",
        "",
        f"Produk: {name}",
        f"Username: `{order['username']}`",
        f"Masa aktif: `{order['days']} Hari`",
        f"Limit device: `{order['device']}`",
        f"Total: *{rupiah(order['price'])}*",
    ]
    if order.get("password"):
        lines.append("Password: `tersimpan untuk pembuatan akun SSH`")
    return "\n".join(lines)


def payment_menu():
    return {
        "inline_keyboard": [
            [{"text": "💳 BAYAR SEKARANG", "callback_data": "order_pay"}],
            [{"text": "❌ Batalkan", "callback_data": "order_cancel"}],
        ]
    }


def begin_public_order(chat_id, product):
    PENDING_ORDER[chat_id] = {
        "stage": "username",
        "product": product,
        "customer_chat_id": chat_id,
        "created_at": time.strftime("%Y-%m-%d %H:%M:%S"),
    }
    save_orders()
    send_message(
        chat_id,
        f"{PRODUCT_NAMES[product]}\n\nMasukkan *username* akun yang Anda inginkan.\n\nGunakan huruf, angka, atau underscore.\nKetik `batal` untuk membatalkan.",
    )


def process_public_order_text(chat_id, text):
    order = PENDING_ORDER.get(chat_id)
    if not order:
        return False

    if text.lower() in ("batal", "cancel", "/cancel"):
        PENDING_ORDER.pop(chat_id, None)
        save_orders()
        send_message(chat_id, "❌ Pesanan dibatalkan.", main_menu(chat_id))
        return True

    stage = order["stage"]

    if stage == "username":
        if not re.fullmatch(r"[A-Za-z0-9_]{1,32}", text):
            send_message(chat_id, "❌ Username tidak valid. Gunakan hanya huruf, angka, dan underscore.")
            return True
        order["username"] = text
        save_orders()
        if order["product"] == "ssh":
            order["stage"] = "password"
            save_orders()
            send_message(chat_id, "🔐 Masukkan *password* akun SSH.")
        else:
            order["stage"] = "days"
            save_orders()
            send_message(
                chat_id,
                "📅 Pilih masa aktif:",
                duration_menu(order["product"])
            )
        return True

    if stage == "password":
        if len(text) < 4 or len(text) > 64 or "\n" in text:
            send_message(chat_id, "❌ Password harus 4–64 karakter.")
            return True
        order["password"] = text
        order["stage"] = "days"
        save_orders()
        send_message(chat_id, "📅 Pilih masa aktif:", duration_menu(order["product"]))
        return True

    return False


def finalize_order_device(chat_id, product, days, device):
    prices = PRICE_TABLE.get(product, {}).get(days, {})
    price = prices.get(device)
    if price is None:
        send_message(chat_id, "❌ Paket tersebut belum tersedia.")
        return
    order = PENDING_ORDER.get(chat_id)
    if not order:
        return
    order.update({
        "stage": "payment",
        "days": days,
        "device": device,
        "price": price,
    })
    save_orders()
    send_message(chat_id, order_summary(order), payment_menu())


# ============================================================
# TEXT
# ============================================================

def account_text(account_type):
    name = PRODUCT_NAMES.get(account_type, account_type.upper())
    return f"{name}\n\nMenu pengelolaan akun."


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
    "trial_vmess": {
        "create": "/etc/ayah-alma/xray/trial-vmess.sh",
    },
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
        env["DEBIAN_FRONTEND"] = "noninteractive"
        # add-vmess.sh memakai variabel shell lowercase `user` untuk username.
        # Jangan biarkan variabel lingkungan `user` dari service membuat loop
        # input username terlewati, sehingga username terbaca sebagai masa aktif.
        if account_type == "vmess" and action == "create":
            env.pop("user", None)

        # Generator Ayah Alma dibuat untuk terminal. Untuk Telegram, buat
        # salinan sementara dan potong bagian menu/read di akhir agar proses
        # tidak menunggu keyboard Telegram. File generator asli tidak diubah.
        run_script = script
        temp_path = None
        content = Path(script).read_text(encoding="utf-8", errors="ignore")

        # Script Ayah Alma dibuat untuk terminal. Telegram tetap mengirim
        # input interaktif yang memang dibutuhkan (misalnya username), tetapi
        # prompt "Tekan apa saja..." dan pemanggilan menu di bagian akhir
        # harus dibuang agar bot tidak menunggu input keyboard.
        lines = content.splitlines()
        cut_at = None
        for index in range(len(lines) - 1, -1, -1):
            stripped = lines[index].strip()
            if re.match(r'^read\s+-n\s+1\s+-s\s+-r\s+-p\s+', stripped):
                cut_at = index
                break

        if cut_at is not None:
            temp = "\n".join(lines[:cut_at]).rstrip() + "\n"
            fd, temp_path = tempfile.mkstemp(prefix="ayah-alma-bot-", suffix=".sh")
            os.close(fd)
            Path(temp_path).write_text(temp, encoding="utf-8")
            os.chmod(temp_path, 0o700)
            run_script = temp_path

        result = subprocess.run(
            ["bash", run_script],
            input=input_text,
            capture_output=True,
            text=True,
            timeout=60,
            cwd="/root",
            env=env,
        )
        output = ((result.stdout or "") + ("\n" + result.stderr if result.stderr else "")).strip()
        output = re.sub(r"\x1b\[[0-9;?]*[ -/]*[@-~]", "", output)
        if not output:
            output = "Selesai tanpa output."
        if result.returncode == 0:
            return "✅ *BERHASIL*\n\n" + output[-3800:]
        return "❌ *SCRIPT GAGAL*\n\n" + output[-3800:]
    except subprocess.TimeoutExpired:
        return "⏱️ Script melebihi batas waktu 60 detik dan dihentikan."
    except Exception as error:
        return f"❌ Error menjalankan script:\n`{error}`"
    finally:
        if 'temp_path' in locals() and temp_path:
            try:
                os.unlink(temp_path)
            except OSError:
                pass

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
            # add-vmess.sh langsung meminta username; tidak memiliki menu opsi 1.
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


def orders_panel_text(waiting_only=False):
    items = []
    keyboard = []
    for customer_id, order in sorted(PENDING_ORDER.items(), key=lambda item: item[1].get("submitted_at", item[1].get("created_at", "")), reverse=True):
        stage = order.get("stage", "unknown")
        if waiting_only and stage != "waiting_payment":
            continue
        product = PRODUCT_NAMES.get(order.get("product", ""), order.get("product", "?").upper())
        username = order.get("username", "belum diisi")
        status_names = {
            "username": "Mengisi username", "password": "Mengisi password SSH",
            "days": "Memilih masa aktif", "device": "Memilih device",
            "payment": "Menunggu klik bayar", "waiting_payment": "Menunggu konfirmasi admin",
        }
        status = status_names.get(stage, stage)
        items.append(
            f"🧾 *{product}*\nUsername: `{username}`\n"
            f"Durasi: `{order.get('days', '-')}` hari | Device: `{order.get('device', '-')}`\n"
            f"Total: *{rupiah(order.get('price', 0)) if order.get('price') is not None else '-'}*\n"
            f"Status: *{status}*\nChat ID: `{customer_id}`"
        )
        if stage == "waiting_payment":
            keyboard.append([
                {"text": f"✅ Konfirmasi {username}", "callback_data": f"pay_confirm_{customer_id}"},
                {"text": f"❌ Tolak {username}", "callback_data": f"pay_reject_{customer_id}"},
            ])
    if not items:
        title = "💰 *PEMBAYARAN MENUNGGU*" if waiting_only else "🧾 *DAFTAR PESANAN*"
        body = title + "\n\nBelum ada pesanan yang tersimpan."
    else:
        title = "💰 *PEMBAYARAN MENUNGGU*" if waiting_only else "🧾 *DAFTAR PESANAN*"
        body = title + "\n\n" + "\n\n━━━━━━━━━━━━\n\n".join(items)
    keyboard.append([{ "text": "🔄 Muat Ulang", "callback_data": "pembayaran" if waiting_only else "pesanan" }])
    keyboard.append([{ "text": "⬅️ Admin Panel", "callback_data": "admin" }])
    return body, {"inline_keyboard": keyboard}


# ============================================================
# PAYMENT / ACCOUNT CREATION
# ============================================================

def notify_admins(text, reply_markup=None):
    for admin_id in get_admin_ids():
        try:
            send_message(admin_id, text, reply_markup)
        except Exception as error:
            print(f"Admin notification error: {error}")


def payment_request(chat_id):
    order = PENDING_ORDER.get(chat_id)
    if not order or order.get("stage") != "payment":
        send_message(chat_id, "❌ Pesanan pembayaran tidak ditemukan.")
        return

    order["stage"] = "waiting_payment"
    order["customer_chat_id"] = chat_id
    order["submitted_at"] = time.strftime("%Y-%m-%d %H:%M:%S")
    save_orders()
    notify_admins(
        "💳 *PESANAN MENUNGGU PEMBAYARAN*\n\n" +
        order_summary(order) +
        f"\n\nCustomer Chat ID: `{chat_id}`",
        {"inline_keyboard": [[
            {"text": "✅ Konfirmasi Bayar", "callback_data": f"pay_confirm_{chat_id}"},
            {"text": "❌ Tolak", "callback_data": f"pay_reject_{chat_id}"},
        ]]}
    )
    send_message(
        chat_id,
        "💳 *PEMBAYARAN*\n\n"
        "Pesanan sudah dibuat dan menunggu konfirmasi pembayaran admin.\n"
        "Setelah pembayaran dikonfirmasi, akun akan dibuat otomatis.",
        {"inline_keyboard": [[{"text": "❌ Batalkan Pesanan", "callback_data": "order_cancel"}]]}
    )


def create_paid_order(chat_id):
    order = PENDING_ORDER.get(chat_id)
    if not order or order.get("stage") != "waiting_payment":
        return "❌ Pesanan tidak ditemukan atau sudah diproses."

    product = order["product"]
    username = order["username"]
    days = order["days"]
    device = order["device"]
    password = order.get("password", "")

    if product == "ssh":
        script_input = f"1\n{username}\n{password}\n{days}\n{device}\n"
    elif product == "vmess":
        # add-vmess.sh langsung meminta username, hari, lalu limit device.
        script_input = f"{username}\n{days}\n{device}\n"
    else:
        script_input = f"{username}\n{days}\n"

    result = run_account_script(product, "create", script_input)
    if result.startswith("✅"):
        PENDING_ORDER.pop(chat_id, None)
        save_orders()
    return result


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
        "reset_trial",
        "menu_vps",
        "restart_xray",
        "restart_ssh"
    )

    if (data in admin_actions or data == "trial_reset_cancel" or data.startswith("trial_reset_confirm_")) and not is_admin(chat_id):
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

    if data in ("trial_vmess", "trial_start"):
        if trial_used(chat_id):
            edit_message(
                chat_id,
                message_id,
                "❌ *TRIAL SUDAH PERNAH DIGUNAKAN*\n\n"
                "Satu ID Telegram hanya mendapatkan trial satu kali.\n"
                "Silakan pilih paket berbayar untuk membuat akun lagi.",
                main_menu(chat_id)
            )
            return

        if not os.path.isfile(TRIAL_SCRIPT):
            edit_message(
                chat_id,
                message_id,
                f"❌ Script trial tidak ditemukan:\n`{TRIAL_SCRIPT}`",
                main_menu(chat_id)
            )
            return

        duration_keyboard = {
            "inline_keyboard": [
                [{"text": "1 Jam", "callback_data": "trial_duration_1"},
                 {"text": "2 Jam", "callback_data": "trial_duration_2"}],
                [{"text": "3 Jam", "callback_data": "trial_duration_3"},
                 {"text": "4 Jam", "callback_data": "trial_duration_4"}],
                [{"text": "5 Jam", "callback_data": "trial_duration_5"},
                 {"text": "24 Jam (1 Hari)", "callback_data": "trial_duration_6"}],
                [{"text": "⬅️ Batal", "callback_data": "back"}],
            ]
        }
        edit_message(
            chat_id,
            message_id,
            "🎁 *TRIAL VMESS*\n\n"
            "Pilih masa aktif trial. Username akan dibuat otomatis.\n"
            "Trial hanya dapat digunakan satu kali per ID Telegram.",
            duration_keyboard
        )
        return

    if data.startswith("trial_duration_"):
        duration = data.rsplit("_", 1)[-1]
        if duration not in {"1", "2", "3", "4", "5", "6"}:
            edit_message(chat_id, message_id, "❌ Durasi trial tidak valid.", main_menu(chat_id))
            return
        if trial_used(chat_id):
            edit_message(
                chat_id, message_id,
                "❌ *TRIAL SUDAH PERNAH DIGUNAKAN*\n\n"
                "Satu ID Telegram hanya mendapatkan trial satu kali.",
                main_menu(chat_id)
            )
            return
        if not os.path.isfile(TRIAL_SCRIPT):
            edit_message(chat_id, message_id,
                         f"❌ Script trial tidak ditemukan:\n`{TRIAL_SCRIPT}`",
                         main_menu(chat_id))
            return

        duration_names = {"1": "1 Jam", "2": "2 Jam", "3": "3 Jam",
                          "4": "4 Jam", "5": "5 Jam", "6": "24 Jam (1 Hari)"}
        edit_message(chat_id, message_id,
                     f"⏳ *Membuat Trial VMess*\nDurasi: {duration_names[duration]}\nUsername dibuat otomatis... ")
        result = run_account_script("trial_vmess", "create", f"{duration}\n")
        if result.startswith("✅"):
            try:
                match = re.search(r"\btrial-[a-z0-9]{4}\b", result, re.IGNORECASE)
                mark_trial_used(chat_id, match.group(0) if match else "otomatis")
            except Exception as error:
                edit_message(
                    chat_id, message_id,
                    "❌ Trial dibuat, tetapi pencatatan ID Telegram gagal. Hubungi admin.\n"
                    f"Error: `{error}`\n\n{result}",
                    main_menu(chat_id)
                )
                return
            edit_message(chat_id, message_id,
                         "🎁 *TRIAL BERHASIL*\n\n" + result[3:].lstrip(),
                         main_menu(chat_id))
        else:
            edit_message(chat_id, message_id, result, main_menu(chat_id))
        return

    if data == "reset_trial":
        PENDING_TRIAL_RESET.pop(chat_id, None)
        PENDING_TRIAL_RESET[chat_id] = "awaiting_id"
        edit_message(
            chat_id,
            message_id,
            "🎁 *RESET LIMIT TRIAL*\n\n"
            "Kirim ID Telegram pengguna yang limit trial-nya ingin direset.\n"
            "Gunakan `/id` pada akun pengguna untuk melihat Chat ID.\n\n"
            "Ketik `batal` untuk membatalkan."
        )
        return

    if data == "trial_reset_cancel":
        PENDING_TRIAL_RESET.pop(chat_id, None)
        edit_message(chat_id, message_id, "❎ Reset trial dibatalkan.", admin_menu())
        return

    if data.startswith("trial_reset_confirm_"):
        target_id = data.rsplit("_", 1)[-1]
        pending_target = PENDING_TRIAL_RESET.get(chat_id)
        if pending_target != target_id or not target_id.isdigit():
            PENDING_TRIAL_RESET.pop(chat_id, None)
            edit_message(chat_id, message_id, "❌ Konfirmasi tidak valid atau sudah kedaluwarsa.", admin_menu())
            return
        PENDING_TRIAL_RESET.pop(chat_id, None)
        try:
            removed = reset_trial_record(target_id)
        except Exception as error:
            edit_message(chat_id, message_id, f"❌ Gagal mereset trial: `{error}`", admin_menu())
            return
        if removed:
            edit_message(
                chat_id, message_id,
                "✅ *LIMIT TRIAL DIRESET*\n\n"
                f"ID Telegram: `{target_id}`\n"
                "Pengguna tersebut dapat mengambil trial lagi. Akun lama tidak dihapus.",
                admin_menu()
            )
        else:
            edit_message(
                chat_id, message_id,
                "ℹ️ Tidak ada catatan trial untuk ID Telegram tersebut.\n"
                f"ID: `{target_id}`",
                admin_menu()
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

    if data.startswith("order_product_"):
        product = data.replace("order_product_", "", 1)
        if product not in PRICE_TABLE:
            edit_message(chat_id, message_id, "❌ Produk tidak tersedia.", product_menu())
            return
        edit_message(chat_id, message_id, f"{PRODUCT_NAMES[product]}\n\n📅 Pilih masa aktif:", duration_menu(product))
        return

    if data.startswith("order_days_"):
        parts = data.split("_")
        if len(parts) != 4 or not parts[3].isdigit():
            edit_message(chat_id, message_id, "❌ Paket tidak valid.", product_menu())
            return
        product = parts[2]
        days = int(parts[3])
        if days not in PRICE_TABLE.get(product, {}):
            edit_message(chat_id, message_id, "❌ Masa aktif belum tersedia.", product_menu())
            return
        order = PENDING_ORDER.get(chat_id)
        if not order or order.get("product") != product or order.get("stage") != "days":
            edit_message(chat_id, message_id, "❌ Sesi pesanan tidak ditemukan. Mulai lagi dari Produk.", product_menu())
            return
        order["days"] = days
        order["stage"] = "device"
        save_orders()
        edit_message(chat_id, message_id, "📱 Pilih limit device dan harga:", device_menu(product, days))
        return

    if data.startswith("order_device_"):
        parts = data.split("_")
        if len(parts) != 5 or not parts[3].isdigit() or not parts[4].isdigit():
            edit_message(chat_id, message_id, "❌ Paket tidak valid.", product_menu())
            return
        product = parts[2]
        days = int(parts[3])
        device = int(parts[4])
        order = PENDING_ORDER.get(chat_id)
        if not order or order.get("stage") != "device":
            edit_message(chat_id, message_id, "❌ Sesi pesanan tidak ditemukan. Mulai lagi dari Produk.", product_menu())
            return
        finalize_order_device(chat_id, product, days, device)
        edit_message(chat_id, message_id, order_summary(PENDING_ORDER[chat_id]), payment_menu())
        return

    if data == "order_pay":
        payment_request(chat_id)
        edit_message(chat_id, message_id, "💳 *PEMBAYARAN*\n\nPesanan dikirim ke admin untuk konfirmasi pembayaran.", {"inline_keyboard": [[{"text": "❌ Batalkan", "callback_data": "order_cancel"}]]})
        return

    if data == "order_cancel":
        PENDING_ORDER.pop(chat_id, None)
        save_orders()
        edit_message(chat_id, message_id, "❌ Pesanan dibatalkan.", main_menu(chat_id))
        return

    if data.startswith("pay_confirm_") or data.startswith("pay_reject_"):
        if not is_admin(chat_id):
            edit_message(chat_id, message_id, "⛔ *AKSES DITOLAK*")
            return
        parts = data.split("_")
        try:
            customer_id = int(parts[2])
        except (ValueError, IndexError):
            edit_message(chat_id, message_id, "❌ Customer ID tidak valid.", admin_menu())
            return
        order = PENDING_ORDER.get(customer_id)
        if not order:
            edit_message(chat_id, message_id, "❌ Pesanan sudah tidak tersedia.", admin_menu())
            return
        if data.startswith("pay_reject_"):
            PENDING_ORDER.pop(customer_id, None)
            save_orders()
            send_message(customer_id, "❌ Pembayaran belum dikonfirmasi. Pesanan dibatalkan.", main_menu(customer_id))
            edit_message(chat_id, message_id, "❌ Pesanan ditolak.", admin_menu())
            return
        send_message(customer_id, "⏳ Pembayaran dikonfirmasi. Akun sedang dibuat...")
        result = create_paid_order(customer_id)
        send_message(customer_id, result, main_menu(customer_id))
        if result.startswith("✅"):
            admin_result = "✅ Pembayaran dikonfirmasi dan akun berhasil dibuat."
        else:
            admin_result = "⚠️ Pembayaran dikonfirmasi, tetapi pembuatan akun gagal. Pesanan tetap tersimpan untuk diperiksa.\n\n" + result[:2500]
        edit_message(chat_id, message_id, admin_result, admin_menu())
        return

    if data.startswith("produk_"):
        product = data.replace("produk_", "", 1)
        if product not in PRICE_TABLE or not PRICE_TABLE.get(product):
            edit_message(chat_id, message_id, product_text(product), product_menu())
            return
        PENDING_ORDER[chat_id] = {
            "stage": "username", "product": product,
            "customer_chat_id": chat_id,
            "created_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        }
        save_orders()
        edit_message(
            chat_id,
            message_id,
            f"{PRODUCT_NAMES[product]}\n\nMasukkan *username* akun yang Anda inginkan.\n\nKetik `batal` untuk membatalkan.",
            {"inline_keyboard": [[{"text": "❌ Batalkan", "callback_data": "order_cancel"}]]}
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
        text, markup = orders_panel_text(waiting_only=False)
        edit_message(chat_id, message_id, text, markup)
        return

    if data == "pembayaran":
        text, markup = orders_panel_text(waiting_only=True)
        edit_message(chat_id, message_id, text, markup)
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

            if chat_id in PENDING_TRIAL_RESET and text:
                if not is_admin(chat_id):
                    PENDING_TRIAL_RESET.pop(chat_id, None)
                    send_message(chat_id, "⛔ Akses ditolak.")
                    return
                if PENDING_TRIAL_RESET.get(chat_id) == "awaiting_id":
                    if process_trial_reset_input(chat_id, text):
                        return

            if chat_id in PENDING_ORDER and text:
                if process_public_order_text(chat_id, text):
                    return

            if chat_id in PENDING_ACCOUNT and text:
                if process_account_input(chat_id, text):
                    return


            if chat_id in PENDING_ORDER and text:
                if process_public_order_text(chat_id, text):
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
