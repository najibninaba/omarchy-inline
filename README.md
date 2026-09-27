# Inline for Omarchy

Local, system-wide inline text completion for the `kasturi` and `jebat-tuf`
Omarchy machines.

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

Kasturi uses `qwen2.5:0.5b` on CPU. Jebat-TUF uses `qwen2.5:1.5b` with CUDA.

## Install

Clone this repository on either supported machine, then run:

```bash
./install.sh
```

The installer adds the model runtime and build dependencies, installs the
Fcitx5 module, daemon, Bash integration, and bar widget, then downloads the
machine's local model. It uses the current `blesh-git` extension API rather
than the older stable ble.sh package. Open a new terminal after installation.

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
```

## Uninstall

```bash
./uninstall.sh
```

The uninstaller retains the model, runtime packages, configuration, and Bash
startup line so it does not remove resources another setup may use.
