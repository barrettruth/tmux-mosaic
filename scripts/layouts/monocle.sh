#!/usr/bin/env bash

_layout_relayout() {
  local win n zoomed
  win=$(_mosaic_resolve_window "${1:-}")
  n=$(_mosaic_window_pane_count "$win")
  _mosaic_can_relayout_window "$win" "$n" || return 0
  zoomed=$(_mosaic_window_zoomed "$win")
  if [[ "$zoomed" != "1" ]]; then
    tmux resize-pane -Z -t "$win" 2>/dev/null || true
  fi

  _mosaic_log "relayout: win=$win n=$n zoomed=$zoomed"
}

_layout_new_pane() { _mosaic_new_pane_append "$1"; }
