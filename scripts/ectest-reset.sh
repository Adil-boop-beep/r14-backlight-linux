#!/bin/bash
# ОДНА пробная запись в EC: сброс счётчика простоя подсветки (0x37) в 0x00.
# Ничего не сохраняется: ec_sys с write_support=1 действует до выгрузки модуля/перезагрузки,
# а сам счётчик EC и так обнуляет при каждом нажатии клавиши.
# Usage: sudo bash ectest-reset.sh
set -e
[ "$(id -u)" = 0 ] || { echo "Нужен root (sudo)"; exit 1; }
DIR="$(dirname "$(readlink -f "$0")")"
LOG="$DIR/../data/ec/ectest-reset.log"
EC=/sys/kernel/debug/ec/ec0/io

# Включаем запись только на время теста
modprobe -r ec_sys 2>/dev/null || true
modprobe ec_sys write_support=1
restore_ro() { modprobe -r ec_sys 2>/dev/null; modprobe ec_sys; echo "ec_sys снова только для чтения."; }
trap restore_ro EXIT

echo "Сейчас нажми Enter и больше НЕ трогай клавиатуру и тачпад ~30 сек."
read -r _

python3 -I - "$EC" "$LOG" <<'EOF'
import sys, time
ec, log = sys.argv[1], sys.argv[2]
CNT, LVL, TARGET = 0x37, 0x19, 0x64      # счётчик, уровень, момент записи (~10 с простоя)
rd = lambda: open(ec, 'rb').read()
f = open(log, 'w')
def say(s): print(s); f.write(s + "\n"); f.flush()

d = rd()
say(f"До: уровень 0x19={d[LVL]}  0x1a={d[0x1a]}  счётчик 0x37=0x{d[CNT]:02x}")
if d[LVL] == 0:
    say("ОТМЕНА: подсветка выключена (уровень 0). Включи её Fn+F1 и запусти снова."); sys.exit(1)

t0 = time.monotonic()
while True:                                # ждём ~10 с простоя, не пишем ничего
    d = rd(); t = time.monotonic() - t0
    if d[CNT] >= 0x96: say("ОТМЕНА: счётчик дошёл до 0x96 раньше записи — запись не сделана."); sys.exit(1)
    if d[CNT] >= TARGET: break
    if t > 20: say(f"ОТМЕНА: счётчик не растёт (0x{d[CNT]:02x}) — запись не сделана."); sys.exit(1)
    time.sleep(0.1)

before = d[CNT]
with open(ec, 'r+b', buffering=0) as w:   # ЕДИНСТВЕННАЯ запись
    w.seek(CNT); w.write(b'\x00')
after = rd()[CNT]
say(f"t={t:.1f} ЗАПИСЬ: 0x37 0x{before:02x} -> 0x00, прочитано обратно 0x{after:02x}")
say("Ожидание: подсветка НЕ гаснет сейчас, а погаснет примерно через 15 с после записи.")

prev = None; t1 = time.monotonic()
while (t := time.monotonic() - t1) < 25:
    c = rd()[CNT]
    if c != prev and (prev is None or c < prev or c == 0x96 or c % 0x10 == 0):
        say(f"  +{t:4.1f} c после записи: 0x37=0x{c:02x}")
    prev = c; time.sleep(0.1)
say(f"Конец: 0x37=0x{prev:02x}. Подсветка должна была погаснуть ~через 15 с после записи.")
EOF
chown "${SUDO_USER:-1000}" "$LOG"
