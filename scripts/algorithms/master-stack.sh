#!/usr/bin/env bash

algo_pane_count() { tmux display-message -p '#{window_panes}'; }
algo_pane_index() { tmux display-message -p '#{pane_index}'; }
algo_pane_base() { tmux display-message -p '#{e|+|:0,#{?pane-base-index,#{pane-base-index},0}}'; }

algo_orientation_for() {
  local win="$1" val
  val=$(mosaic_get_w "@mosaic-orientation" "left" "$win")
  case "$val" in
  left | right | top | bottom)
    echo "$val"
    ;;
  *)
    mosaic_log "orientation: invalid=$val win=$win defaulting=left"
    echo "left"
    ;;
  esac
}

algo_layout_for() {
  case "$1" in
  left) echo "main-vertical" ;;
  right) echo "main-vertical-mirrored" ;;
  top) echo "main-horizontal" ;;
  bottom) echo "main-horizontal-mirrored" ;;
  esac
}

algo_main_option_for() {
  case "$1" in
  left | right) echo "main-pane-width" ;;
  top | bottom) echo "main-pane-height" ;;
  esac
}

algo_full_layout_for() {
  case "$1" in
  left | right) echo "even-vertical" ;;
  top | bottom) echo "even-horizontal" ;;
  esac
}

algo_join_flag_for() {
  case "$1" in
  left | right) echo "-v" ;;
  top | bottom) echo "-h" ;;
  esac
}

algo_apply_layout() {
  local win="$1" orientation="$2" mfact="$3"
  tmux set-window-option -t "$win" "$(algo_main_option_for "$orientation")" "${mfact}%" 2>/dev/null || true
  tmux select-layout -t "$win" "$(algo_layout_for "$orientation")" 2>/dev/null || true
}

algo_mfact_for() {
  local win="$1"
  local val
  val=$(tmux show-option -wqv -t "$win" "@mosaic-mfact" 2>/dev/null)
  [[ -n "$val" ]] && {
    echo "$val"
    return
  }
  mosaic_get "@mosaic-mfact" "50"
}

algo_join_extra_masters() {
  local win="$1" orientation="$2" nmaster="$3" n="$4" pbase="$5"
  local flag idx
  flag=$(algo_join_flag_for "$orientation")
  for ((idx = pbase + 1; idx < pbase + nmaster; idx++)); do
    tmux join-pane -d "$flag" -s "$win.$idx" -t "$win.$((idx - 1))" 2>/dev/null || true
  done
  [[ "$nmaster" -gt 2 ]] && tmux select-layout -t "$win.$pbase" -E 2>/dev/null || true
  [[ $((n - nmaster)) -gt 1 ]] && tmux select-layout -t "$win.$((pbase + nmaster))" -E 2>/dev/null || true
}

algo_relayout() {
  local win n mfact orientation nmaster pbase
  win=$(mosaic_resolve_window "${1:-}")
  n=$(mosaic_window_pane_count "$win")
  mosaic_can_relayout_window "$win" "$n" || return 0
  mfact=$(algo_mfact_for "$win")
  orientation=$(algo_orientation_for "$win")
  nmaster=$(mosaic_effective_nmaster "$win" "$n")
  pbase=$(algo_pane_base)

  algo_apply_layout "$win" "$orientation" "$mfact"
  if [[ "$nmaster" -ge "$n" ]]; then
    tmux select-layout -t "$win" "$(algo_full_layout_for "$orientation")" 2>/dev/null || true
  elif [[ "$nmaster" -gt 1 ]]; then
    algo_join_extra_masters "$win" "$orientation" "$nmaster" "$n" "$pbase"
  fi

  mosaic_log "relayout: win=$win n=$n orientation=$orientation nmaster=$nmaster mfact=$mfact"
}

algo_toggle() { mosaic_toggle_window algo_relayout; }

algo_promote() {
  local idx n pbase
  idx=$(algo_pane_index)
  n=$(algo_pane_count)
  pbase=$(algo_pane_base)

  [[ "$n" -le 1 ]] && return 0

  if [[ "$idx" -eq "$pbase" ]]; then
    mosaic_swap_keep_focus -s ":.$pbase" -t ":.$((pbase + 1))"
  else
    mosaic_bubble_keep_focus "$idx" "$pbase"
  fi
  algo_relayout
}

algo_resize_master() {
  local delta="${1:-}"
  if [[ -z "$delta" ]]; then
    delta=$(mosaic_get "@mosaic-step" "5")
  fi
  local win cur new
  win=$(mosaic_current_window)
  cur=$(algo_mfact_for "$win")
  new=$((cur + delta))
  [[ "$new" -lt 5 ]] && new=5
  [[ "$new" -gt 95 ]] && new=95
  tmux set-option -wq -t "$win" "@mosaic-mfact" "$new"
  algo_relayout "$win"
}

algo_sync_state() {
  local win="$1"
  mosaic_enabled "$win" || return 0
  [[ "$(mosaic_window_zoomed "$win")" == "1" ]] && return 0

  local n nmaster
  n=$(mosaic_window_pane_count "$win")
  [[ "$n" -le 1 ]] && return 0
  nmaster=$(mosaic_effective_nmaster "$win" "$n")
  [[ "$nmaster" -ge "$n" ]] && return 0

  local pbase pane_size window_size pct orientation
  orientation=$(algo_orientation_for "$win")
  pbase=$(algo_pane_base)
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

  tmux set-option -wq -t "$win" "@mosaic-mfact" "$pct"
  mosaic_log "sync-state: win=$win orientation=$orientation pane_size=$pane_size window_size=$window_size pct=$pct"
}
