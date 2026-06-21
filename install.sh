#!/usr/bin/env bash
# penbind installer — desktop-agnostic pen-button mapper.
# Run from the repo directory:  ./install.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.local/bin/penbind"
UNIT="$HOME/.config/systemd/user/penbind.service"
UDEV="/etc/udev/rules.d/70-penbind.rules"
# Input-device name glob used to grant this user read access to the pen.
# Adjust if your pen reports a different name (see: penbind status / evtest).
NAME_GLOB="${PENBIND_NAME_GLOB:-*Active Pen*}"

echo "==> 1/5 installing python3-evdev"
if ! python3 -c 'import evdev' 2>/dev/null; then
  sudo dnf install -y python3-evdev
fi

echo "==> 2/5 installing penbind to $BIN"
install -Dm755 "$HERE/penbind" "$BIN"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "    note: add ~/.local/bin to PATH (e.g. in ~/.bashrc) to call 'penbind' directly";;
esac

echo "==> 3/5 udev rule for device access (uaccess; no re-login needed)"
sudo tee "$UDEV" >/dev/null <<EOF
# Grant the active-session user access to the pen's input device so penbind can
# read (and grab) it without being in the 'input' group.
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="$NAME_GLOB", TAG+="uaccess"
EOF
sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=input || true

echo "==> 4/5 installing systemd --user service"
mkdir -p "$(dirname "$UNIT")"
sed "s|%h/.local/bin/penbind|$BIN|" "$HERE/penbind.service" > "$UNIT"
systemctl --user daemon-reload

echo "==> 5/5 done"
cat <<EOF

Next steps:
  1. Make sure the pen is connected (penbind pair   # if not paired yet).
     If it was already connected, briefly disconnect/reconnect it once so the
     new udev access rule applies (toggle Bluetooth or re-press the top button).
  2. Learn the buttons and choose actions:
        penbind learn
  3. Enable the background daemon:
        systemctl --user enable --now penbind
  4. Check things:
        penbind status
        systemctl --user status penbind

To change actions later:   penbind configure   &&  systemctl --user restart penbind
EOF
