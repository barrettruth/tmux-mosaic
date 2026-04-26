#!/usr/bin/env bash

_layout_pane_count() { tmux display-message -p '#{window_panes}'; }
_layout_pane_index() { tmux display-message -p '#{pane_index}'; }
_layout_pane_base() { tmux display-message -p '#{e|+|:0,#{?pane-base-index,#{pane-base-index},0}}'; }

_layout_apply_layout() {
  local win="$1" mfact="$2"
  tmux set-window-option -t "$win" main-pane-height "${mfact}%" 2>/dev/null || true
  tmux select-layout -t "$win" main-horizontal 2>/dev/null || true
}

_layout_join_extra_masters() {
  local win="$1" nmaster="$2" n="$3" pbase="$4"
  local idx
  for ((idx = pbase + 1; idx < pbase + nmaster; idx++)); do
    tmux join-pane -d -h -s "$win.$idx" -t "$win.$((idx - 1))" 2>/dev/null || true
  done
  [[ "$nmaster" -gt 2 ]] && tmux select-layout -t "$win.$pbase" -E 2>/dev/null || true
  [[ $((n - nmaster)) -gt 1 ]] && tmux select-layout -t "$win.$((pbase + nmaster))" -E 2>/dev/null || true
}

_layout_relayout() {
  local win n mfact nmaster pbase
  win=$(_mosaic_resolve_window "${1:-}")
  n=$(_mosaic_window_pane_count "$win")
  _mosaic_can_relayout_window "$win" "$n" || return 0
  mfact=$(_mosaic_mfact_for "$win")
  nmaster=$(_mosaic_effective_nmaster "$win" "$n")
  pbase=$(_layout_pane_base)

  _layout_apply_layout "$win" "$mfact"
  if [[ "$nmaster" -ge "$n" ]]; then
    tmux select-layout -t "$win" even-horizontal 2>/dev/null || true
  elif [[ "$nmaster" -gt 1 ]]; then
    _layout_join_extra_masters "$win" "$nmaster" "$n" "$pbase"
  fi

  _mosaic_log "relayout: win=$win n=$n layout=bottom-stack nmaster=$nmaster mfact=$mfact"
}

_layout_toggle() { _mosaic_toggle_window; }

_layout_promote() {
  local idx n pbase
  idx=$(_layout_pane_index)
  n=$(_layout_pane_count)
  pbase=$(_layout_pane_base)

  [[ "$n" -le 1 ]] && return 0

  if [[ "$idx" -eq "$pbase" ]]; then
    _mosaic_swap_keep_focus -s ":.$pbase" -t ":.$((pbase + 1))"
  else
    _mosaic_bubble_keep_focus "$idx" "$pbase"
  fi
  _layout_relayout
}

_layout_resize_master() {
  local delta="${1:-}"
  if [[ -z "$delta" ]]; then
    delta=$(_mosaic_get "@mosaic-step" "5")
  fi
  local win cur new
  win=$(_mosaic_current_window)
  cur=$(_mosaic_mfact_for "$win")
  new=$((cur + delta))
  [[ "$new" -lt 5 ]] && new=5
  [[ "$new" -gt 95 ]] && new=95
  tmux set-option -wq -t "$win" "@mosaic-mfact" "$new"
}

_layout_sync_state() {
  local win="$1"
  _mosaic_enabled "$win" || return 0
  [[ "$(_mosaic_window_zoomed "$win")" == "1" ]] && return 0

  local n nmaster
  n=$(_mosaic_window_pane_count "$win")
  [[ "$n" -le 1 ]] && return 0
  nmaster=$(_mosaic_effective_nmaster "$win" "$n")
  [[ "$nmaster" -ge "$n" ]] && return 0

  local pbase pane_size window_size pct
  pbase=$(_layout_pane_base)
  pane_size=$(tmux display-message -p -t "$win.$pbase" '#{pane_height}' 2>/dev/null)
  window_size=$(tmux display-message -p -t "$win" '#{window_height}' 2>/dev/null)
  [[ -z "$pane_size" ]] && return 0
  [[ -z "$window_size" || "$window_size" -le 0 ]] && return 0

  pct=$((pane_size * 100 / window_size))
  [[ "$pct" -lt 5 ]] && pct=5
  [[ "$pct" -gt 95 ]] && pct=95

  _mosaic_sync_mfact "$win" "$pct"
  _mosaic_log "sync-state: win=$win layout=bottom-stack pane_size=$pane_size window_size=$window_size pct=$pct"
}
