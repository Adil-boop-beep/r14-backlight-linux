#!/bin/bash
# Read-only: logs every EC register change for N seconds.
# Usage: ecwatch.sh <label> [seconds]   e.g. ecwatch.sh idle 60 ; ecwatch.sh levels 40
LABEL="${1:-idle}"
DUR="${2:-60}"
OUT="$(dirname "$(readlink -f "$0")")/../data/ec/ecwatch-$LABEL.log"
EC=/sys/kernel/debug/ec/ec0/io
modprobe ec_sys   # без write_support=1 — только чтение
case "$LABEL" in
  idle)   echo "НЕ трогай клавиатуру и тачпад $DUR сек. Дождись, пока подсветка погаснет, и подожди до конца." ;;
  levels) echo "Каждые ~5 сек нажимай Fn+F1 (переключение уровней), пройди все уровни 2 круга, клавиши между этим не трогай." ;;
  *)      echo "Запись $DUR сек." ;;
esac
sleep 1
python3 -I - "$EC" "$DUR" "$OUT" <<'EOF'
import sys, time
ec, dur, out = sys.argv[1], float(sys.argv[2]), sys.argv[3]
read = lambda: open(ec, 'rb').read()
prev = read(); t0 = time.monotonic()
with open(out, 'w') as f:
    f.write("t=0.0 START " + prev.hex() + "\n")
    while (t := time.monotonic() - t0) < dur:
        time.sleep(0.1)
        cur = read()
        ch = [f"{i:02x}:{prev[i]:02x}->{cur[i]:02x}" for i in range(len(cur)) if cur[i] != prev[i]]
        if ch:
            f.write(f"t={t:.1f} " + " ".join(ch) + "\n"); f.flush()
        prev = cur
    f.write(f"t={t:.1f} END " + prev.hex() + "\n")
print("Готово:", out)
EOF
chown "${SUDO_USER:-1000}" "$OUT"
