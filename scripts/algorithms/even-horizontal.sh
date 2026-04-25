#!/usr/bin/env bash

algo_relayout() {
  local win="${1:-}"
  [[ -z "$win" ]] && win=$(tmux display-message -p '#{window_id}')

  if ! mosaic_enabled "$win"; then
    mosaic_log "relayout: disabled on $win, skipping"
    return 0
  fi

  local n
  n=$(tmux list-panes -t "$win" 2>/dev/null | wc -l)
  [[ "$n" -le 1 ]] && return 0

  tmux select-layout -t "$win" even-horizontal 2>/dev/null || true

  mosaic_log "relayout: win=$win n=$n"
}

algo_toggle() {
  local win
  win=$(tmux display-message -p '#{window_id}')
  if mosaic_enabled "$win"; then
    tmux set-option -wqu -t "$win" "@mosaic-enabled" 2>/dev/null
    tmux display-message "mosaic: off"
  else
    tmux set-option -wq -t "$win" "@mosaic-enabled" 1
    tmux display-message "mosaic: on"
    algo_relayout "$win"
  fi
}
