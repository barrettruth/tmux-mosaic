#!/usr/bin/env bash

_layout_orientation_for() {
  local win="$1" val
  val=$(_mosaic_get_w "@mosaic-orientation" "left" "$win")
  case "$val" in
  left | right | top | bottom)
    printf '%s\n' "$val"
    ;;
  *)
    _mosaic_log "orientation: invalid=$val win=$win defaulting=left"
    printf '%s\n' "left"
    ;;
  esac
}

_layout_layout_for() {
  case "$1" in
  left) printf '%s\n' "main-vertical" ;;
  right) printf '%s\n' "main-vertical-mirrored" ;;
  top) printf '%s\n' "main-horizontal" ;;
  bottom) printf '%s\n' "main-horizontal-mirrored" ;;
  esac
}

_layout_master_pane_option_for() {
  case "$1" in
  left | right) printf '%s\n' "main-pane-width" ;;
  top | bottom) printf '%s\n' "main-pane-height" ;;
  esac
}

_layout_full_layout_for() {
  case "$1" in
  left | right) printf '%s\n' "even-vertical" ;;
  top | bottom) printf '%s\n' "even-horizontal" ;;
  esac
}

_layout_join_flag_for() {
  case "$1" in
  left | right) printf '%s\n' "-v" ;;
  top | bottom) printf '%s\n' "-h" ;;
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
  pbase=$(_mosaic_window_pane_base "$win")

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
    pbase=$(_mosaic_window_pane_base "$win")
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
  idx=$(_mosaic_current_pane_index)
  n=$(_mosaic_window_pane_count)
  pbase=$(_mosaic_window_pane_base)

  [[ "$n" -le 1 ]] && return 0

  if [[ "$idx" -eq "$pbase" ]]; then
    _mosaic_swap_keep_focus -s ":.$pbase" -t ":.$((pbase + 1))"
  else
    _mosaic_bubble_keep_focus "$idx" "$pbase"
  fi
  _layout_relayout
}

_layout_resize_master() {
  _mosaic_resize_master_current_window "$@"
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
  pbase=$(_mosaic_window_pane_base "$win")
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

  pct=$(_mosaic_clamp_percent "$((pane_size * 100 / window_size))")

  _mosaic_sync_mfact "$win" "$pct"
  _mosaic_log "sync-state: win=$win orientation=$orientation pane_size=$pane_size window_size=$window_size pct=$pct"
}
