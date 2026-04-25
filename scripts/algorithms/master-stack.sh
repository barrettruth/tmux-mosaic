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

algo_swap_keep_focus() {
  local pid
  pid=$(tmux display-message -p '#{pane_id}')
  tmux swap-pane "$@"
  tmux select-pane -t "$pid"
}

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

  local mfact orientation
  mfact=$(algo_mfact_for "$win")
  orientation=$(algo_orientation_for "$win")

  algo_apply_layout "$win" "$orientation" "$mfact"

  mosaic_log "relayout: win=$win n=$n orientation=$orientation mfact=$mfact"
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

algo_promote() {
  local idx n pbase
  idx=$(algo_pane_index)
  n=$(algo_pane_count)
  pbase=$(algo_pane_base)

  [[ "$n" -le 1 ]] && return 0

  if [[ "$idx" -eq "$pbase" ]]; then
    algo_swap_keep_focus -s ":.$pbase" -t ":.$((pbase + 1))"
  else
    algo_swap_keep_focus -s ":.$idx" -t ":.$pbase"
  fi
  algo_relayout
}

algo_resize_master() {
  local delta="${1:-}"
  if [[ -z "$delta" ]]; then
    delta=$(mosaic_get "@mosaic-step" "5")
  fi
  local win cur new
  win=$(tmux display-message -p '#{window_id}')
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
  [[ "$(tmux display-message -p -t "$win" '#{window_zoomed_flag}')" == "1" ]] && return 0

  local n
  n=$(tmux list-panes -t "$win" 2>/dev/null | wc -l)
  [[ "$n" -le 1 ]] && return 0

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
