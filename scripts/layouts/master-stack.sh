#!/usr/bin/env bash

_layout_pane_count() { tmux display-message -p '#{window_panes}'; }
_layout_pane_index() { tmux display-message -p '#{pane_index}'; }
_layout_pane_base() { tmux display-message -p '#{e|+|:0,#{?pane-base-index,#{pane-base-index},0}}'; }

_layout_orientation_for() {
  local win="$1" val
  val=$(_mosaic_get_w "@mosaic-orientation" "left" "$win")
  case "$val" in
  left | right | top | bottom)
    echo "$val"
    ;;
  *)
    _mosaic_log "orientation: invalid=$val win=$win defaulting=left"
    echo "left"
    ;;
  esac
}

_layout_layout_for() {
  case "$1" in
  left) echo "main-vertical" ;;
  right) echo "main-vertical-mirrored" ;;
  top) echo "main-horizontal" ;;
  bottom) echo "main-horizontal-mirrored" ;;
  esac
}

_layout_master_pane_option_for() {
  case "$1" in
  left | right) echo "main-pane-width" ;;
  top | bottom) echo "main-pane-height" ;;
  esac
}

_layout_full_layout_for() {
  case "$1" in
  left | right) echo "even-vertical" ;;
  top | bottom) echo "even-horizontal" ;;
  esac
}

_layout_join_flag_for() {
  case "$1" in
  left | right) echo "-v" ;;
  top | bottom) echo "-h" ;;
  esac
}

_layout_apply_layout() {
  local win="$1" orientation="$2" mfact="$3"
  tmux set-window-option -t "$win" "$(_layout_master_pane_option_for "$orientation")" "${mfact}%" 2>/dev/null || true
  tmux select-layout -t "$win" "$(_layout_layout_for "$orientation")" 2>/dev/null || true
}

_layout_join_extra_masters() {
  local win="$1" orientation="$2" nmaster="$3" n="$4" pbase="$5"
  local flag idx
  flag=$(_layout_join_flag_for "$orientation")
  for ((idx = pbase + 1; idx < pbase + nmaster; idx++)); do
    tmux join-pane -d "$flag" -s "$win.$idx" -t "$win.$((idx - 1))" 2>/dev/null || true
  done
  [[ "$nmaster" -gt 2 ]] && tmux select-layout -t "$win.$pbase" -E 2>/dev/null || true
  [[ $((n - nmaster)) -gt 1 ]] && tmux select-layout -t "$win.$((pbase + nmaster))" -E 2>/dev/null || true
}

_layout_new_pane_first_stack() {
  local win="$1" orientation="$2" target
  local -a flags=()
  target=$(_mosaic_window_last_pane "$win")
  case "$orientation" in
  left | right) flags=(-h) ;;
  esac
  _mosaic_new_pane_split_or_append "$win" "$target" "${flags[@]}"
}

_layout_relayout() {
  local win n mfact orientation nmaster pbase
  win=$(_mosaic_resolve_window "${1:-}")
  n=$(_mosaic_window_pane_count "$win")
  _mosaic_can_relayout_window "$win" "$n" || return 0
  mfact=$(_mosaic_mfact_for "$win")
  orientation=$(_layout_orientation_for "$win")
  nmaster=$(_mosaic_effective_nmaster "$win" "$n")
  pbase=$(_layout_pane_base)

  _layout_apply_layout "$win" "$orientation" "$mfact"
  if [[ "$nmaster" -ge "$n" ]]; then
    tmux select-layout -t "$win" "$(_layout_full_layout_for "$orientation")" 2>/dev/null || true
  elif [[ "$nmaster" -gt 1 ]]; then
    _layout_join_extra_masters "$win" "$orientation" "$nmaster" "$n" "$pbase"
  fi

  _mosaic_log "relayout: win=$win n=$n orientation=$orientation nmaster=$nmaster mfact=$mfact"
}

_layout_new_pane_all_masters() {
  local win="$1" orientation="$2" n="$3" pbase="$4" target pane
  local -a flags=()
  case "$orientation" in
  left)
    target=$(_mosaic_window_last_pane "$win")
    flags=(-h)
    ;;
  right)
    target="$win.$pbase"
    flags=(-h -b)
    ;;
  top)
    target=$(_mosaic_window_last_pane "$win")
    ;;
  bottom)
    target="$win.$pbase"
    flags=(-b)
    ;;
  esac
  pane=$(_mosaic_new_pane_split_or_append "$win" "$target" "${flags[@]}") || return 1
  case "$orientation" in
  right | bottom)
    if [[ "$pane" != "$(_mosaic_window_last_pane "$win")" ]]; then
      _mosaic_bubble_keep_focus "$pbase" "$((pbase + n))"
    fi
    ;;
  esac
  printf '%s\n' "$pane"
}

_layout_toggle() { _mosaic_toggle_window; }
_layout_new_pane() {
  local win n nmaster orientation target pbase
  local -a flags=()
  win=$(_mosaic_resolve_window "${1:-}")
  n=$(_mosaic_window_pane_count "$win")
  nmaster=$(_mosaic_effective_nmaster "$win" "$n")
  if [[ "$nmaster" -eq 1 && "$n" -eq 1 ]]; then
    orientation=$(_layout_orientation_for "$win")
    _layout_new_pane_first_stack "$win" "$orientation"
    return
  fi
  if [[ "$n" -lt "$nmaster" ]]; then
    _mosaic_new_pane_append "$win"
    return
  fi
  orientation=$(_layout_orientation_for "$win")
  if [[ "$n" -eq "$nmaster" ]]; then
    pbase=$(_layout_pane_base)
    _layout_new_pane_all_masters "$win" "$orientation" "$n" "$pbase"
    return
  fi
  target=$(_mosaic_window_last_pane "$win")
  case "$orientation" in
  top | bottom) flags=(-h) ;;
  esac
  _mosaic_new_pane_split_or_append "$win" "$target" "${flags[@]}"
}

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

  local pbase pane_size window_size pct orientation
  orientation=$(_layout_orientation_for "$win")
  pbase=$(_layout_pane_base)
  case "$orientation" in
  left | right)
    pane_size=$(tmux display-message -p -t "$win.$pbase" '#{pane_width}' 2>/dev/null)
    window_size=$(tmux display-message -p -t "$win" '#{window_width}' 2>/dev/null)
    ;;
  top | bottom)
    pane_size=$(tmux display-message -p -t "$win.$pbase" '#{pane_height}' 2>/dev/null)
    window_size=$(tmux display-message -p -t "$win" '#{window_height}' 2>/dev/null)
    ;;
  esac
  [[ -z "$pane_size" ]] && return 0
  [[ -z "$window_size" || "$window_size" -le 0 ]] && return 0

  pct=$((pane_size * 100 / window_size))
  [[ "$pct" -lt 5 ]] && pct=5
  [[ "$pct" -gt 95 ]] && pct=95

  _mosaic_sync_mfact "$win" "$pct"
  _mosaic_log "sync-state: win=$win orientation=$orientation pane_size=$pane_size window_size=$window_size pct=$pct"
}
