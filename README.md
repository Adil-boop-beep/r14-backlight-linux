# r14-backlight

[Русская версия](README.ru.md)

Keeps the keyboard backlight of the **Machcreator Genesis R14** laptop on in Linux.

Out of the box, the embedded controller (EC) turns the backlight off after 15 seconds without input,
and it only comes back on a key press. There is no vendor software and no BIOS option for this.
This project is a small systemd service that keeps the backlight lit at whatever level you pick with **Fn+F1**.

> **Status:** experimental. A single test write to the EC worked as expected.
> The service still needs more real-world testing, especially after suspend/resume.

## How it works

The keyboard backlight is controlled entirely by the EC firmware. ACPI (DSDT/SSDT) and WMI expose
no interface for it, so the service reads and writes EC registers directly through the kernel's
`ec_sys` module (`/sys/kernel/debug/ec/ec0/io`).

| EC offset | Meaning | Behaviour |
|---|---|---|
| `0x37` | idle counter | +1 every 100 ms, reset to 0 by any key press or Fn+F1. Stops at `0x96` (150 = 15.0 s), and the backlight turns off |
| `0x19` | backlight level | 0 = off, 1–4. Fn+F1 cycles 0→1→2→3→4→0 |
| `0x1a` | copy of `0x19` | always changes together with it |

When the backlight times out, the level does not change: only the counter reaches the limit.
No mode or timeout-threshold register was found, so the service resets the counter instead.

About once a second the daemon reads `0x19` and `0x37`. It writes `0x00` to `0x37` only when all three are true:

- the level is not 0 (the backlight was turned on with Fn+F1),
- the lid is open,
- the counter has reached `0x50` (8 s idle).

That is about one write every 8 seconds, the same thing the EC does on every key press.
At level 0 the service never writes anything, so Fn+F1 still works normally, including turning the backlight off.

## Requirements

- Machcreator Genesis R14 (board `N140TRB01_MB`; developed on BIOS 0.42). The installer refuses to run on other models.
- Linux with systemd, `python3`, and the `ec_sys` kernel module (included in the stock Arch kernel).
- Root access to install.

## Install

```sh
sudo bash install.sh
```

The installer copies the daemon to `/usr/local/lib/r14-backlight/` and the unit to
`/etc/systemd/system/r14-backlight.service`, then enables and starts the service.

To check it: turn the backlight on with Fn+F1 and leave the keyboard and touchpad alone for more than 15 seconds.
The backlight should stay on.

```sh
systemctl status r14-backlight
journalctl -u r14-backlight -b --no-pager | tail
```

## Configuration

Uncomment and edit these lines in `/etc/systemd/system/r14-backlight.service`, then run `systemctl daemon-reload && systemctl restart r14-backlight`:

| Variable | Default | Meaning |
|---|---|---|
| `R14_RESET_AT` | `0x50` | reset the counter once it reaches this value (100 ms ticks, must be below `0x96`) |
| `R14_POLL` | `1.0` | poll interval, seconds |

## Uninstall

```sh
sudo bash uninstall.sh
```

## Safety

- Write access to the EC is enabled (`ec_sys write_support=1`) only while the service runs.
  When the service stops, `ec_sys` is reloaded read-only. Reboot resets it in any case.
- The only register the service writes is `0x37`, and the only value it writes is `0x00`.
  It never touches temperature, fan, battery or other registers.
- The unit runs with `ProtectSystem=strict`, `ProtectHome=yes`, `PrivateTmp=yes` and `NoNewPrivileges=yes`.
- Writing to EC registers is at your own risk. These offsets were found on one specific laptop and BIOS version.

## Not tested yet

- Behaviour after suspend/resume. If the backlight is off after waking up, a key press should bring it back.
- Whether writing `0` brings back a backlight that has already timed out (`0x37 = 0x96`) without a key press.

## Project layout

```
install.sh, uninstall.sh       install / remove the service
src/r14-backlightd.py          the daemon
systemd/r14-backlight.service  systemd unit
scripts/dump.sh                dump ACPI tables and an EC snapshot (read-only)
scripts/ecwatch.sh             log EC register changes over time (read-only)
scripts/ectest-reset.sh        single test write 0x37 := 0x00
NOTES.md                       research notes (Russian)
LICENSE                        MIT
```

The research scripts write their output to `data/`, which is not part of the repository.

## Credits

- **R14Backlight** for Windows by *noLive* (4PDA, "Machcreator Genesis R14" thread) showed that the
  backlight is controlled through EC registers and that the EC has an idle counter.
- [vaio-sx14r-keyboard-backlight-kern-module-linux](https://github.com/windymelt/vaio-sx14r-keyboard-backlight-kern-module-linux):
  a similar EC-based approach for the VAIO SX-14R.
