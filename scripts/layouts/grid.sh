#!/usr/bin/env bash

_layout_relayout() { _mosaic_relayout_simple tiled "${1:-}"; }

_layout_global_reshape_count() {
  local n="$1" k
  [[ "$n" -ge 4 ]] || return 1
  for ((k = 2; k * k <= n; k++)); do
    if [[ "$n" -eq $((k * k)) || "$n" -eq $((k * (k + 1))) ]]; then
      return 0
    fi
  done
  return 1
}

_layout_toggle() { _mosaic_toggle_window; }
_layout_new_pane() {
  local win n target
  win=$(_mosaic_resolve_window "${1:-}")
  n=$(_mosaic_window_pane_count "$win")
  target=$(_mosaic_window_last_pane "$win")
  if [[ "$n" -eq 1 || "$n" -eq 2 ]] || _layout_global_reshape_count "$n"; then
    _mosaic_new_pane_split_or_append "$win" "$target"
    return
  fi
  _mosaic_new_pane_split_or_append "$win" "$target" -h
}
