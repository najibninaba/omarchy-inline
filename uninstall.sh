#!/usr/bin/env bash

set -euo pipefail

systemctl --user disable --now omarchy-inline.service 2>/dev/null || true
if command -v omarchy >/dev/null; then
  omarchy plugin disable najib.inline 2>/dev/null || true
fi

rm -f "$HOME/.config/systemd/user/omarchy-inline.service"
rm -f "$HOME/.local/bin/omarchy-inline"
rm -rf "$HOME/.config/omarchy/plugins/najib.inline"

if (( EUID == 0 )); then
  rm -f /usr/lib/fcitx5/inlinecompletion.so /usr/share/fcitx5/addon/inlinecompletion.conf
else
  sudo rm -f /usr/lib/fcitx5/inlinecompletion.so /usr/share/fcitx5/addon/inlinecompletion.conf
fi

systemctl --user daemon-reload
systemctl --user restart omarchy-fcitx5.service 2>/dev/null || true
omarchy-shell shell rescanPlugins 2>/dev/null || true

echo "Inline removed. Its config, Ollama, model, ble.sh, and .bashrc line were retained."
