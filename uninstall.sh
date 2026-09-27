#!/usr/bin/env bash

set -euo pipefail

systemctl --user disable --now cotypist.service 2>/dev/null || true
if command -v omarchy >/dev/null; then
  omarchy plugin disable najib.cotypist 2>/dev/null || true
fi

rm -f "$HOME/.config/systemd/user/cotypist.service"
rm -f "$HOME/.local/bin/cotypist"
rm -rf "$HOME/.config/omarchy/plugins/najib.cotypist"

if (( EUID == 0 )); then
  rm -f /usr/lib/fcitx5/cotypist.so /usr/share/fcitx5/addon/cotypist.conf
else
  sudo rm -f /usr/lib/fcitx5/cotypist.so /usr/share/fcitx5/addon/cotypist.conf
fi

systemctl --user daemon-reload
systemctl --user restart omarchy-fcitx5.service 2>/dev/null || true
omarchy-shell shell rescanPlugins 2>/dev/null || true

echo "Cotypist removed. Its config, Ollama, model, ble.sh, and .bashrc line were retained."
