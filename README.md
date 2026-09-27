# Inline for Omarchy

Private, local AI text completion for Omarchy applications and Bash. Inline
combines a Quattro bar widget with a native Fcitx5 module, a local completion
daemon, Ollama, and a ble.sh terminal integration.

## What it does

- Shows inline completions in compatible Wayland GUI text fields through an
  Fcitx5 module.
- Accepts one suggested word at a time with Tab in GUI fields. Tab is consumed
  only while a suggestion is visible.
- Shows native ghost text in Omarchy's Bash/Foot terminal through ble.sh.
- Accepts the next terminal word with Alt+Right or Ctrl+Right while preserving
  Bash's normal Tab completion.
- Runs inference locally through Ollama. Text does not leave the machine.
- Never runs in password, sensitive, disabled, or generic terminal Fcitx
  contexts. Raw-mode agent TUIs retain their own input handling.
- Adds an Omarchy bar widget for status and pause/resume.

## Supported systems

Inline includes two hardware profiles:

- `cpu` (default): CPU inference with `qwen2.5:0.5b`
- `nvidia`: NVIDIA CUDA inference with `qwen2.5:1.5b`

## Install

Inline requires manual setup because `omarchy plugin add` intentionally only
clones and validates shell plugins; it never executes installers or uses sudo.

Add the plugin, then run its reviewed setup script:

```bash
omarchy plugin add https://github.com/najibninaba/omarchy-inline
~/.config/omarchy/plugins/io.github.najibninaba.inline/setup
```

On a machine with an NVIDIA GPU, select the NVIDIA profile explicitly:

```bash
~/.config/omarchy/plugins/io.github.najibninaba.inline/setup --profile nvidia
```

Setup displays its changes and asks before proceeding. It installs Arch build
and runtime packages, builds the Fcitx5 module from this checkout, installs the
daemon and user service, adds a marked block to `~/.bashrc`, enables Ollama,
and downloads the configured model. It uses `sudo` for packages, the system
Fcitx5 module, and Ollama's system service. Open a new terminal afterward.

## Use

- GUI apps: type normally, then press Tab to accept the next suggested word.
- Bash in Foot: press Alt+Right or Ctrl+Right to accept the next suggested
  word. Normal Tab completion remains unchanged.
- Right-click the bar icon to pause or resume completion.

Agent TUIs such as Amp, Claude Code, Codex, Gemini, and OpenCode use raw terminal
input and are intentionally not intercepted. Their own prompt editors must
offer ghost text for truly inline TUI completion; forcing an input method over
them would break shortcuts and Tab behavior.

## Configuration

Edit `~/.config/omarchy-inline/config.toml`, then restart the daemon:

```bash
systemctl --user restart omarchy-inline.service
```

## Verify

```bash
scripts/check
systemctl --user status omarchy-inline.service
omarchy-inline status
omarchy plugin validate ~/.config/omarchy/plugins/io.github.najibninaba.inline
```

`scripts/check` runs unit tests and, when the tools are available, ShellCheck,
the native CMake build, and Omarchy's official plugin validator.

## Update

Update the plugin checkout, then rerun setup so the native module and daemon
match the QML source:

```bash
omarchy plugin update io.github.najibninaba.inline
~/.config/omarchy/plugins/io.github.najibninaba.inline/setup
```

## Uninstall

```bash
~/.config/omarchy/plugins/io.github.najibninaba.inline/uninstall
omarchy plugin remove io.github.najibninaba.inline
```

Run `uninstall` before removing the plugin checkout. It removes Inline-owned
native files, the daemon, user service, and marked Bash block. It retains the
configuration, Ollama, models, and shared packages.

## Architecture and security

- The QML widget only invokes the fixed `omarchy-inline status` and `toggle`
  commands.
- The Fcitx5 module and Bash integration use an owner-only Unix socket under
  `$XDG_RUNTIME_DIR/omarchy-inline`.
- The daemon sends completion requests only to the configured local Ollama
  endpoint. Text does not leave the machine with the default configuration.
- Password, sensitive, disabled, and generic terminal Fcitx contexts are
  excluded. Raw-mode agent TUIs are not intercepted.
- The systemd user service runs with a read-only home and restricted kernel,
  namespace, privilege, and network access.

Omarchy plugins run unsandboxed inside the long-lived shell process. Review
this repository and its setup script before enabling it.
