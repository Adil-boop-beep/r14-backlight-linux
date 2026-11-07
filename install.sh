#!/bin/bash
# Установка службы r14-backlight. Usage: sudo bash install.sh
set -e
[ "$(id -u)" = 0 ] || { echo "Нужен root (sudo)"; exit 1; }
DIR="$(dirname "$(readlink -f "$0")")"
[ "$(cat /sys/class/dmi/id/product_name)" = "Genesis R14" ] || { echo "Это не Machcreator Genesis R14 — отмена."; exit 1; }
install -Dm755 "$DIR/src/r14-backlightd.py" /usr/local/lib/r14-backlight/r14-backlightd.py
install -Dm644 "$DIR/systemd/r14-backlight.service" /etc/systemd/system/r14-backlight.service
systemctl daemon-reload
systemctl enable --now r14-backlight.service
systemctl --no-pager status r14-backlight.service | head -n 12
