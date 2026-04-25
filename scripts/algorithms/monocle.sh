#!/usr/bin/env bash

algo_relayout() {
  local win="${1:-}"
  [[ -z "$win" ]] && win=$(tmux display-message -p '#{window_id}')

  if ! mosaic_enabled "$win"; then
    mosaic_log "relayout: disabled on $win, skipping"
    return 0
  fi

  local n zoomed
  n=$(tmux list-panes -t "$win" 2>/dev/null | wc -l)
  [[ "$n" -le 1 ]] && return 0

  zoomed=$(tmux display-message -p -t "$win" '#{window_zoomed_flag}')
  if [[ "$zoomed" != "1" ]]; then
    tmux resize-pane -Z -t "$win" 2>/dev/null || true
  fi

  mosaic_log "relayout: win=$win n=$n zoomed=$zoomed"
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
