#!/usr/bin/python3 -I
"""Держит подсветку клавиатуры Machcreator Genesis R14 включённой.

EC сам гасит подсветку, когда счётчик простоя 0x37 (тик 100 мс) доходит до 0x96 (15 с).
Демон раз в секунду читает уровень 0x19 и счётчик 0x37; если уровень != 0 (подсветка
включена через Fn+F1) и счётчик >= порога, пишет 0x37 := 0 — то же, что делает EC при нажатии.
При уровне 0 (выключено через Fn+F1) и при закрытой крышке ничего не пишет.
"""
import glob, os, signal, sys, time

EC = "/sys/kernel/debug/ec/ec0/io"
REG_LEVEL, REG_IDLE = 0x19, 0x37
EC_TIMEOUT = 0x96                                       # порог EC, 15,0 с
RESET_AT = int(os.environ.get("R14_RESET_AT", "0x50"), 0)  # сбрасывать с 8 с простоя
POLL = float(os.environ.get("R14_POLL", "1.0"))

running = True
def stop(*_):
    global running
    running = False
signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)

def log(msg):
    print(msg, flush=True)

def lid_closed():
    for p in glob.glob("/proc/acpi/button/lid/*/state"):
        try:
            if "closed" in open(p).read():
                return True
        except OSError:
            pass
    return False

def main():
    if not (0 < RESET_AT < EC_TIMEOUT):
        log(f"R14_RESET_AT=0x{RESET_AT:02x} вне диапазона 0x01..0x95"); return 2
    try:
        fd = os.open(EC, os.O_RDWR)
    except OSError as e:
        log(f"Не открыть {EC} на запись: {e}. Нужен ec_sys write_support=1."); return 1

    log(f"Старт: сброс 0x{REG_IDLE:02x} при >= 0x{RESET_AT:02x}, опрос {POLL} с")
    last_level, writes = None, 0
    while running:
        try:
            level = os.pread(fd, 1, REG_LEVEL)[0]
            idle = os.pread(fd, 1, REG_IDLE)[0]
            if level != last_level:
                log(f"Уровень подсветки: {level}" + (" (выкл — не трогаю)" if level == 0 else ""))
                last_level = level
            if level != 0 and idle >= RESET_AT and not lid_closed():
                os.pwrite(fd, b"\x00", REG_IDLE)
                writes += 1
        except OSError as e:
            log(f"Ошибка доступа к EC: {e}")
            time.sleep(5)
        time.sleep(POLL)
    os.close(fd)
    log(f"Остановлен, сбросов счётчика: {writes}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
