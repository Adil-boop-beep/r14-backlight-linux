#!/bin/bash
# Read-only: dumps ACPI tables and EC register snapshot for analysis.
set -e
OUT="$(dirname "$(readlink -f "$0")")/../data/acpi"
mkdir -p "$OUT"
pacman -S --needed --noconfirm acpica
cp /sys/firmware/acpi/tables/DSDT "$OUT/dsdt.dat"
for t in /sys/firmware/acpi/tables/SSDT*; do cp "$t" "$OUT/$(basename "$t" | tr A-Z a-z).dat"; done
cd "$OUT" && { iasl -e ssdt*.dat -d dsdt.dat >/dev/null 2>&1 || iasl -d dsdt.dat >/dev/null 2>&1 || true; }
for f in ssdt*.dat; do iasl -d "$f" >/dev/null 2>&1 || true; done
# EC snapshot (read-only mode of ec_sys)
modprobe ec_sys
xxd /sys/kernel/debug/ec/ec0/io > "$OUT/../ec/ec_snapshot.txt"
chown -R "${SUDO_USER:-1000}" "$OUT" "$OUT/../ec/ec_snapshot.txt"
echo "Готово: $OUT"; ls "$OUT"
