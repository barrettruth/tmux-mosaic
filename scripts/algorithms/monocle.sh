#!/usr/bin/env bash

algo_relayout() {
  local win n zoomed
  win=$(mosaic_resolve_window "${1:-}")
  n=$(mosaic_window_pane_count "$win")
  mosaic_can_relayout_window "$win" "$n" || return 0
  zoomed=$(mosaic_window_zoomed "$win")
  if [[ "$zoomed" != "1" ]]; then
    tmux resize-pane -Z -t "$win" 2>/dev/null || true
  fi

  mosaic_log "relayout: win=$win n=$n zoomed=$zoomed"
}

algo_toggle() { mosaic_toggle_window algo_relayout; }
