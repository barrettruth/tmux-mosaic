#!/usr/bin/env bash

algo_pane_count() { tmux display-message -p '#{window_panes}'; }
algo_pane_index() { tmux display-message -p '#{pane_index}'; }
algo_pane_base() { tmux display-message -p '#{e|+|:0,#{?pane-base-index,#{pane-base-index},0}}'; }

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

algo_layout_checksum() {
  local layout="$1" csum=0 i ch
  for ((i = 0; i < ${#layout}; i++)); do
    printf -v ch '%d' "'${layout:i:1}"
    csum=$(((csum >> 1) | ((csum & 1) << 15)))
    csum=$(((csum + ch) & 0xffff))
  done
  printf '%04x\n' "$csum"
}

algo_layout_leaf_id=0

algo_layout_leaf() {
  local __out="$1" sx="$2" sy="$3" x="$4" y="$5" id="$algo_layout_leaf_id"
  algo_layout_leaf_id=$((algo_layout_leaf_id + 1))
  printf -v "$__out" '%sx%s,%s,%s,%s' "$sx" "$sy" "$x" "$y" "$id"
}

algo_layout_split_primary() {
  local __first="$1" __second="$2" total="$3" pct="$4"
  local first max second
  first=$((total * pct / 100))
  max=$((total - 2))
  [[ "$max" -lt 1 ]] && max=1
  [[ "$first" -lt 1 ]] && first=1
  [[ "$first" -gt "$max" ]] && first=$max
  second=$((total - first - 1))
  printf -v "$__first" '%s' "$first"
  printf -v "$__second" '%s' "$second"
}

algo_layout_split_half() {
  local __first="$1" __second="$2" total="$3"
  local usable first second
  usable=$((total - 1))
  first=$(((usable + 1) / 2))
  second=$((usable - first))
  printf -v "$__first" '%s' "$first"
  printf -v "$__second" '%s' "$second"
}

algo_layout_node() {
  local __out="$1" sx="$2" sy="$3" x="$4" y="$5" n="$6" step="$7" mfact="$8"
  local node_a_var="${__out}_a" node_b_var="${__out}_b" first_size second_size

  if [[ "$n" -eq 1 ]]; then
    algo_layout_leaf "$__out" "$sx" "$sy" "$x" "$y"
    return
  fi

  case "$step" in
  0)
    algo_layout_split_primary first_size second_size "$sx" "$mfact"
    algo_layout_leaf "$node_a_var" "$first_size" "$sy" "$x" "$y"
    algo_layout_node "$node_b_var" "$second_size" "$sy" "$((x + first_size + 1))" "$y" "$((n - 1))" 1 "$mfact"
    printf -v "$__out" '%sx%s,%s,%s{%s,%s}' "$sx" "$sy" "$x" "$y" "${!node_a_var}" "${!node_b_var}"
    ;;
  1)
    algo_layout_split_half first_size second_size "$sy"
    algo_layout_leaf "$node_a_var" "$sx" "$first_size" "$x" "$y"
    algo_layout_node "$node_b_var" "$sx" "$second_size" "$x" "$((y + first_size + 1))" "$((n - 1))" 2 "$mfact"
    printf -v "$__out" '%sx%s,%s,%s[%s,%s]' "$sx" "$sy" "$x" "$y" "${!node_a_var}" "${!node_b_var}"
    ;;
  2)
    algo_layout_split_half first_size second_size "$sx"
    algo_layout_node "$node_a_var" "$first_size" "$sy" "$x" "$y" "$((n - 1))" 3 "$mfact"
    algo_layout_leaf "$node_b_var" "$second_size" "$sy" "$((x + first_size + 1))" "$y"
    printf -v "$__out" '%sx%s,%s,%s{%s,%s}' "$sx" "$sy" "$x" "$y" "${!node_a_var}" "${!node_b_var}"
    ;;
  3)
    algo_layout_split_half first_size second_size "$sy"
    algo_layout_node "$node_a_var" "$sx" "$first_size" "$x" "$y" "$((n - 1))" 4 "$mfact"
    algo_layout_leaf "$node_b_var" "$sx" "$second_size" "$x" "$((y + first_size + 1))"
    printf -v "$__out" '%sx%s,%s,%s[%s,%s]' "$sx" "$sy" "$x" "$y" "${!node_a_var}" "${!node_b_var}"
    ;;
  4)
    algo_layout_split_half first_size second_size "$sx"
    algo_layout_leaf "$node_a_var" "$first_size" "$sy" "$x" "$y"
    algo_layout_node "$node_b_var" "$second_size" "$sy" "$((x + first_size + 1))" "$y" "$((n - 1))" 1 "$mfact"
    printf -v "$__out" '%sx%s,%s,%s{%s,%s}' "$sx" "$sy" "$x" "$y" "${!node_a_var}" "${!node_b_var}"
    ;;
  esac
}

algo_layout_body() {
  local __out="$1" sx="$2" sy="$3" n="$4" mfact="$5"
  local layout
  algo_layout_leaf_id=0
  algo_layout_node layout "$sx" "$sy" 0 0 "$n" 0 "$mfact"
  printf -v "$__out" '%s' "$layout"
}

algo_apply_layout() {
  local win="$1" n="$2" mfact="$3"
  local sx sy body
  sx=$(tmux display-message -p -t "$win" '#{window_width}' 2>/dev/null)
  sy=$(tmux display-message -p -t "$win" '#{window_height}' 2>/dev/null)
  [[ -z "$sx" || -z "$sy" ]] && return 0
  algo_layout_body body "$sx" "$sy" "$n" "$mfact"
  tmux select-layout -t "$win" "$(algo_layout_checksum "$body"),$body" 2>/dev/null || true
}

algo_swap_keep_focus() {
  local pid
  pid=$(tmux display-message -p '#{pane_id}')
  tmux swap-pane "$@"
  tmux select-pane -t "$pid"
}

algo_bubble_keep_focus() {
  local from="$1" to="$2"
  while [[ "$from" -gt "$to" ]]; do
    algo_swap_keep_focus -s ":.$from" -t ":.$((from - 1))"
    from=$((from - 1))
  done
}

algo_relayout() {
  local win n mfact pbase
  win=$(mosaic_resolve_window "${1:-}")
  n=$(mosaic_window_pane_count "$win")
  mosaic_can_relayout_window "$win" "$n" || return 0
  mfact=$(algo_mfact_for "$win")
  pbase=$(algo_pane_base)

  algo_apply_layout "$win" "$n" "$mfact"

  mosaic_log "relayout: win=$win n=$n layout=spiral mfact=$mfact pbase=$pbase"
}

algo_toggle() { mosaic_toggle_window algo_relayout; }

algo_promote() {
  local idx n pbase
  idx=$(algo_pane_index)
  n=$(algo_pane_count)
  pbase=$(algo_pane_base)

  [[ "$n" -le 1 ]] && return 0

  if [[ "$idx" -eq "$pbase" ]]; then
    algo_swap_keep_focus -s ":.$pbase" -t ":.$((pbase + 1))"
  else
    algo_bubble_keep_focus "$idx" "$pbase"
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

  local n
  n=$(mosaic_window_pane_count "$win")
  [[ "$n" -le 1 ]] && return 0

  local pbase pane_size window_size pct
  pbase=$(algo_pane_base)
  pane_size=$(tmux display-message -p -t "$win.$pbase" '#{pane_width}' 2>/dev/null)
  window_size=$(tmux display-message -p -t "$win" '#{window_width}' 2>/dev/null)
  [[ -z "$pane_size" ]] && return 0
  [[ -z "$window_size" || "$window_size" -le 0 ]] && return 0

  pct=$((pane_size * 100 / window_size))
  [[ "$pct" -lt 5 ]] && pct=5
  [[ "$pct" -gt 95 ]] && pct=95

  tmux set-option -wq -t "$win" "@mosaic-mfact" "$pct"
  mosaic_log "sync-state: win=$win layout=spiral pbase=$pbase pane_size=$pane_size window_size=$window_size pct=$pct"
}
