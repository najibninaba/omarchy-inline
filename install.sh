#!/usr/bin/env bash

set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
host=$(hostname -s)
case "$host" in
  kasturi) profile=kasturi; ollama_package=ollama ;;
  jebat-tuf) profile=jebat-tuf; ollama_package=ollama-cuda ;;
  *)
    echo "Unsupported host '$host'. Expected kasturi or jebat-tuf." >&2
    exit 1
    ;;
esac

command -v omarchy >/dev/null || { echo "This installer requires Omarchy." >&2; exit 1; }

for package in cmake extra-cmake-modules gcc ninja fcitx5 "$ollama_package" blesh-git; do
  pacman -Q "$package" >/dev/null 2>&1 || omarchy pkg add "$package"
done

install -Dm0755 "$root_dir/src/daemon/cotypist" "$HOME/.local/bin/cotypist"
install -Dm0644 "$root_dir/src/config/config.$profile.toml" \
  "$HOME/.config/cotypist-omarchy/config.toml"
install -Dm0644 "$root_dir/src/systemd/cotypist.service" \
  "$HOME/.config/systemd/user/cotypist.service"
install -Dm0644 "$root_dir/src/bash/cotypist.bash" \
  "$HOME/.config/cotypist-omarchy/cotypist.bash"

plugin_dir="$HOME/.config/omarchy/plugins/najib.cotypist"
install -d "$plugin_dir"
install -m0644 "$root_dir/src/plugin/manifest.json" "$plugin_dir/manifest.json"
install -m0644 "$root_dir/src/plugin/Panel.qml" "$plugin_dir/Panel.qml"

cmake -S "$root_dir/src/fcitx" -B "$root_dir/build/fcitx" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib
cmake --build "$root_dir/build/fcitx"
sudo cmake --install "$root_dir/build/fcitx"

bashrc_line='[[ -r /usr/share/blesh/ble.sh ]] && source /usr/share/blesh/ble.sh --attach=none; [[ -r "$HOME/.config/cotypist-omarchy/cotypist.bash" ]] && source "$HOME/.config/cotypist-omarchy/cotypist.bash"; [[ ${BLE_VERSION-} ]] && ble-attach'
grep -Fqx "$bashrc_line" "$HOME/.bashrc" || printf '\n%s\n' "$bashrc_line" >> "$HOME/.bashrc"

sudo systemctl enable --now ollama.service
ollama pull "$(sed -n 's/^model = "\(.*\)"/\1/p' "$HOME/.config/cotypist-omarchy/config.toml")"
systemctl --user daemon-reload
systemctl --user enable --now cotypist.service
systemctl --user restart omarchy-fcitx5.service

omarchy plugin validate "$plugin_dir"
omarchy-shell shell rescanPlugins
omarchy plugin enable najib.cotypist right
omarchy restart shell

echo "Cotypist installed for $profile. Open a new terminal for Bash ghost text."
