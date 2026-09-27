# Inline's Bash UI uses ble.sh's native asynchronous ghost-text machinery.

[[ $- == *i* ]] || return 0
[[ ${BLE_VERSION-} ]] || return 0

ble-import util.bgproc

function ble/inline/server {
  exec "$HOME/.local/bin/omarchy-inline" stream
}

function ble/inline/open {
  ble/util/bgproc#opened _ble_inline && return 0
  ble/util/bgproc#open _ble_inline ble/inline/server \
    'deferred:restart:timeout=30000:kill-timeout=500'
}

function ble/inline/read-one {
  local encoded IFS=
  ble/bash/read -r encoded <&"${_ble_inline_bgproc[0]}" || return
  local ret
  ret=$(printf '%s' "$encoded" | base64 -d 2>/dev/null) || return
  ble/string#quote-word "$ret" always
  ble/util/print "ret=$ret"
}

function ble/complete/auto-complete/source:inline {
  ((_ble_edit_ind == ${#_ble_edit_str})) || return 1
  [[ $_ble_edit_str ]] || return 1

  local request=$_ble_edit_str request_point=$_ble_edit_ind
  ble/inline/open || return 1

  local stale IFS=
  while ble/util/is-stdin-ready "${_ble_inline_bgproc[0]}"; do
    ble/bash/read -r stale <&"${_ble_inline_bgproc[0]}" || break
  done

  local encoded
  encoded=$(printf '%s' "$request" | base64 -w0) || return 1
  ble/util/bgproc#post _ble_inline "$encoded" || return 1

  local code='ble/inline/read-one' packed
  ble/util/assign packed \
    'ble/util/conditional-sync "$code" "" 20 "progressive-weight:timeout=3000:killall"' || return 1
  builtin eval -- "$packed"
  local completion=$ret

  [[ $_ble_edit_str == "$request" && $_ble_edit_ind == "$request_point" ]] || return 1
  [[ $completion ]] || return 1
  local suggestion=$request$completion
  ble/complete/auto-complete/enter h 0 "$completion" '' "$suggestion"
}

function ble/inline/install {
  ble/inline/open || return
  ble/array#unshift _ble_complete_auto_source inline
  bleopt complete_auto_delay=180
  ble-face auto_complete='fg=240,italic'
  ble-bind -m auto_complete -f M-right 'auto_complete/@end insert-word'
  ble-bind -m auto_complete -f C-right 'auto_complete/@end insert-cword'
}

ble/util/import/eval-after-load core-complete 'ble/inline/install'
