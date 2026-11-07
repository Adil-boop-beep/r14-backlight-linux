#!/bin/bash
# Удаление службы r14-backlight. Usage: sudo bash uninstall.sh
[ "$(id -u)" = 0 ] || { echo "Нужен root (sudo)"; exit 1; }
systemctl disable --now r14-backlight.service 2>/dev/null
rm -f /etc/systemd/system/r14-backlight.service
rm -rf /usr/local/lib/r14-backlight
systemctl daemon-reload
echo "Удалено. ec_sys возвращён в режим только чтения (служба делает это при остановке)."
