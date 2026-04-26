#!/usr/bin/env bash

mosaic_get() {
  local opt="$1" default="$2"
  local val
  val=$(tmux show-option -gqv "$opt" 2>/dev/null)
  printf '%s\n' "${val:-$default}"
}

mosaic_get_w() {
  local opt="$1" default="$2" target="${3:-}"
  local val
  if [[ -n "$target" ]]; then
    val=$(tmux show-option -wqvA -t "$target" "$opt" 2>/dev/null)
  else
    val=$(tmux show-option -wqvA "$opt" 2>/dev/null)
  fi
  printf '%s\n' "${val:-$default}"
}

mosaic_get_gw() {
  local opt="$1" default="$2"
  local val
  val=$(tmux show-option -gwqv "$opt" 2>/dev/null)
  printf '%s\n' "${val:-$default}"
}

mosaic_get_w_raw() {
  local opt="$1" target="${2:-}"
  local val
  if [[ -n "$target" ]]; then
    val=$(tmux show-option -wqv -t "$target" "$opt" 2>/dev/null)
  else
    val=$(tmux show-option -wqv "$opt" 2>/dev/null)
  fi
  printf '%s\n' "$val"
}

mosaic_local_algorithm() {
  local target="${1:-}"
  mosaic_get_w_raw "@mosaic-algorithm" "$target"
}

mosaic_global_algorithm() {
  mosaic_get_gw "@mosaic-algorithm" ""
}

mosaic_algorithm_for_window() {
  local target="${1:-}" val
  val=$(mosaic_local_algorithm "$target")
  case "$val" in
  off)
    printf '\n'
    return 0
    ;;
  '')
    ;;
  *)
    printf '%s\n' "$val"
    return 0
    ;;
  esac

  val=$(mosaic_global_algorithm)
  case "$val" in
  '' | off) printf '\n' ;;
  *) printf '%s\n' "$val" ;;
  esac
}

mosaic_window_has_local_algorithm() {
  local target="${1:-}" val
  val=$(mosaic_local_algorithm "$target")
  [[ -n "$val" && "$val" != "off" ]]
}

mosaic_window_has_algorithm() {
  local target="${1:-}"
  [[ -n "$(mosaic_algorithm_for_window "$target")" ]]
}

mosaic_enabled() {
  local target="${1:-}"
  mosaic_window_has_algorithm "$target"
}

mosaic_current_window() { tmux display-message -p '#{window_id}'; }

mosaic_resolve_window() {
  local win="${1:-$(mosaic_current_window)}"
  printf '%s\n' "$win"
}

mosaic_window_pane_count() {
  tmux display-message -p -t "$(mosaic_resolve_window "${1:-}")" '#{window_panes}'
}

mosaic_window_zoomed() {
  tmux display-message -p -t "$(mosaic_resolve_window "${1:-}")" '#{window_zoomed_flag}'
}

mosaic_nmaster_for() {
  local target="${1:-}" val
  val=$(mosaic_get_w "@mosaic-nmaster" "1" "$target")
  [[ "$val" =~ ^[1-9][0-9]*$ ]] || {
    mosaic_log "nmaster: invalid=$val target=$target defaulting=1"
    val=1
  }
  printf '%s\n' "$val"
}

mosaic_effective_nmaster() {
  local target="${1:-}" n="${2:-}" val
  [[ -n "$n" ]] || n=$(mosaic_window_pane_count "$target")
  val=$(mosaic_nmaster_for "$target")
  [[ "$val" -gt "$n" ]] && val=$n
  printf '%s\n' "$val"
}

mosaic_first_client() {
  tmux list-clients -F '#{client_name}' 2>/dev/null | head -n1
}

mosaic_mfact_for() {
  local win="$1" val
  val=$(tmux show-option -wqvA -t "$win" "@mosaic-mfact" 2>/dev/null)
  [[ -n "$val" ]] && {
    printf '%s\n' "$val"
    return
  }
  mosaic_get "@mosaic-mfact" "50"
}

mosaic_compute_fingerprint() {
  local win="$1" algo="$2"
  local n mfact nmaster orientation window_w window_h zoomed
  n=$(mosaic_window_pane_count "$win")
  mfact=$(mosaic_get_w "@mosaic-mfact" "50" "$win")
  nmaster=$(mosaic_get_w "@mosaic-nmaster" "1" "$win")
  orientation=$(mosaic_get_w "@mosaic-orientation" "left" "$win")
  window_w=$(tmux display-message -p -t "$win" '#{window_width}' 2>/dev/null)
  window_h=$(tmux display-message -p -t "$win" '#{window_height}' 2>/dev/null)
  zoomed=$(mosaic_window_zoomed "$win")
  printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
    "$algo" "$n" "$mfact" "$nmaster" "$orientation" "$window_w" "$window_h" "$zoomed"
}

mosaic_fingerprint_get() {
  mosaic_get_w_raw "@mosaic-_fingerprint" "${1:-}"
}

mosaic_pending_fingerprint_get() {
  mosaic_get_w_raw "@mosaic-_pending-fingerprint" "${1:-}"
}

mosaic_fingerprint_set() {
  local win="$1" fp="$2"
  tmux set-option -wq -t "$win" "@mosaic-_fingerprint" "$fp"
}

mosaic_fingerprint_unset() {
  tmux set-option -wqu -t "$1" "@mosaic-_fingerprint" 2>/dev/null
}

mosaic_pending_fingerprint_set() {
  local win="$1" fp="$2"
  tmux set-option -wq -t "$win" "@mosaic-_pending-fingerprint" "$fp"
}

mosaic_pending_fingerprint_unset() {
  tmux set-option -wqu -t "$1" "@mosaic-_pending-fingerprint" 2>/dev/null
}

mosaic_sync_mfact() {
  local win="$1" pct="$2" current
  current=$(mosaic_get_w_raw "@mosaic-mfact" "$win")
  [[ "$current" == "$pct" ]] && return 0
  tmux set-option -wq -t "$win" "@mosaic-mfact" "$pct"
}

mosaic_show_message() {
  local message="$*" client
  client=$(tmux display-message -p '#{client_name}' 2>/dev/null)
  [[ -z "$client" ]] && client=$(mosaic_first_client)
  if [[ -n "$client" ]]; then
    tmux display-message -c "$client" "$message"
  else
    printf '%s\n' "$message" >&2
  fi
}

mosaic_can_relayout_window() {
  local win="$1" n="$2"
  if ! mosaic_enabled "$win"; then
    mosaic_log "relayout: disabled on $win, skipping"
    return 1
  fi
  [[ "$n" -gt 1 ]]
}

mosaic_toggle_window() {
  local win local_algo global_algo
  win=$(mosaic_current_window)
  local_algo=$(mosaic_local_algorithm "$win")
  global_algo=$(mosaic_global_algorithm)

  if [[ "$local_algo" == "off" ]]; then
    if [[ -n "$global_algo" && "$global_algo" != "off" ]]; then
      tmux set-option -wqu -t "$win" "@mosaic-algorithm" 2>/dev/null
      mosaic_show_message "mosaic: on"
    else
      mosaic_show_message "mosaic: no layout configured"
    fi
  elif [[ -n "$local_algo" ]]; then
    if [[ -n "$global_algo" && "$global_algo" != "off" ]]; then
      tmux set-option -wq -t "$win" "@mosaic-algorithm" "off"
    else
      tmux set-option -wqu -t "$win" "@mosaic-algorithm" 2>/dev/null
    fi
    mosaic_show_message "mosaic: off"
  elif [[ -n "$global_algo" && "$global_algo" != "off" ]]; then
    tmux set-option -wq -t "$win" "@mosaic-algorithm" "off"
    mosaic_show_message "mosaic: off"
  else
    mosaic_show_message "mosaic: no layout configured"
  fi
}

mosaic_relayout_simple() {
  local layout="$1" win n
  win=$(mosaic_resolve_window "${2:-}")
  n=$(mosaic_window_pane_count "$win")
  mosaic_can_relayout_window "$win" "$n" || return 0
  tmux select-layout -t "$win" "$layout" 2>/dev/null || true
  mosaic_log "relayout: win=$win n=$n layout=$layout"
}

mosaic_current_pane_index() { tmux display-message -p '#{pane_index}'; }

mosaic_current_pane_base() {
  tmux display-message -p '#{e|+|:0,#{?pane-base-index,#{pane-base-index},0}}'
}

mosaic_swap_keep_focus() {
  local pid
  pid=$(tmux display-message -p '#{pane_id}')
  tmux swap-pane "$@"
  tmux select-pane -t "$pid"
}

mosaic_bubble_keep_focus() {
  local from="$1" to="$2"
  while [[ "$from" -gt "$to" ]]; do
    mosaic_swap_keep_focus -s ":.$from" -t ":.$((from - 1))"
    from=$((from - 1))
  done
  while [[ "$from" -lt "$to" ]]; do
    mosaic_swap_keep_focus -s ":.$from" -t ":.$((from + 1))"
    from=$((from + 1))
  done
}

mosaic_fibonacci_variant() {
  if declare -f algo_fibonacci_variant >/dev/null 2>&1; then
    algo_fibonacci_variant
  else
    printf '%s\n' "spiral"
  fi
}

mosaic_fibonacci_layout_checksum() {
  local layout="$1" csum=0 i ch
  for ((i = 0; i < ${#layout}; i++)); do
    printf -v ch '%d' "'${layout:i:1}"
    csum=$(((csum >> 1) | ((csum & 1) << 15)))
    csum=$(((csum + ch) & 0xffff))
  done
  printf '%04x\n' "$csum"
}

mosaic_fibonacci_layout_leaf_id=0

mosaic_fibonacci_layout_leaf() {
  local __out="$1" sx="$2" sy="$3" x="$4" y="$5" id="$mosaic_fibonacci_layout_leaf_id"
  mosaic_fibonacci_layout_leaf_id=$((mosaic_fibonacci_layout_leaf_id + 1))
  printf -v "$__out" '%sx%s,%s,%s,%s' "$sx" "$sy" "$x" "$y" "$id"
}

mosaic_fibonacci_layout_split_primary() {
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

mosaic_fibonacci_layout_split_half() {
  local __first="$1" __second="$2" total="$3"
  local usable first second
  usable=$((total - 1))
  first=$(((usable + 1) / 2))
  second=$((usable - first))
  printf -v "$__first" '%s' "$first"
  printf -v "$__second" '%s' "$second"
}

mosaic_fibonacci_layout_step() {
  local __split="$1" __order="$2" __next="$3" step="$4"
  local variant value_split value_order value_next
  variant=$(mosaic_fibonacci_variant)
  case "$variant:$step" in
  spiral:0 | dwindle:0)
    value_split="primary"
    value_order="leaf-node"
    value_next=1
    ;;
  spiral:1 | dwindle:1)
    value_split="y"
    value_order="leaf-node"
    value_next=2
    ;;
  spiral:2)
    value_split="x"
    value_order="node-leaf"
    value_next=3
    ;;
  spiral:3)
    value_split="y"
    value_order="node-leaf"
    value_next=4
    ;;
  spiral:4)
    value_split="x"
    value_order="leaf-node"
    value_next=1
    ;;
  dwindle:2)
    value_split="x"
    value_order="leaf-node"
    value_next=1
    ;;
  esac
  printf -v "$__split" '%s' "$value_split"
  printf -v "$__order" '%s' "$value_order"
  printf -v "$__next" '%s' "$value_next"
}

mosaic_fibonacci_layout_node() {
  local __out="$1" sx="$2" sy="$3" x="$4" y="$5" n="$6" step="$7" mfact="$8"
  local split order next axis container
  local node_a_var="${__out}_a" node_b_var="${__out}_b" first_size second_size

  if [[ "$n" -eq 1 ]]; then
    mosaic_fibonacci_layout_leaf "$__out" "$sx" "$sy" "$x" "$y"
    return
  fi

  mosaic_fibonacci_layout_step split order next "$step"
  case "$split" in
  primary)
    mosaic_fibonacci_layout_split_primary first_size second_size "$sx" "$mfact"
    axis="x"
    container="{}"
    ;;
  x)
    mosaic_fibonacci_layout_split_half first_size second_size "$sx"
    axis="x"
    container="{}"
    ;;
  y)
    mosaic_fibonacci_layout_split_half first_size second_size "$sy"
    axis="y"
    container="[]"
    ;;
  esac

  if [[ "$axis" == "x" ]]; then
    if [[ "$order" == "leaf-node" ]]; then
      mosaic_fibonacci_layout_leaf "$node_a_var" "$first_size" "$sy" "$x" "$y"
      mosaic_fibonacci_layout_node "$node_b_var" "$second_size" "$sy" "$((x + first_size + 1))" "$y" "$((n - 1))" "$next" "$mfact"
    else
      mosaic_fibonacci_layout_node "$node_a_var" "$first_size" "$sy" "$x" "$y" "$((n - 1))" "$next" "$mfact"
      mosaic_fibonacci_layout_leaf "$node_b_var" "$second_size" "$sy" "$((x + first_size + 1))" "$y"
    fi
  else
    if [[ "$order" == "leaf-node" ]]; then
      mosaic_fibonacci_layout_leaf "$node_a_var" "$sx" "$first_size" "$x" "$y"
      mosaic_fibonacci_layout_node "$node_b_var" "$sx" "$second_size" "$x" "$((y + first_size + 1))" "$((n - 1))" "$next" "$mfact"
    else
      mosaic_fibonacci_layout_node "$node_a_var" "$sx" "$first_size" "$x" "$y" "$((n - 1))" "$next" "$mfact"
      mosaic_fibonacci_layout_leaf "$node_b_var" "$sx" "$second_size" "$x" "$((y + first_size + 1))"
    fi
  fi

  if [[ "$container" == "{}" ]]; then
    printf -v "$__out" '%sx%s,%s,%s{%s,%s}' "$sx" "$sy" "$x" "$y" "${!node_a_var}" "${!node_b_var}"
  else
    printf -v "$__out" '%sx%s,%s,%s[%s,%s]' "$sx" "$sy" "$x" "$y" "${!node_a_var}" "${!node_b_var}"
  fi
}

mosaic_fibonacci_layout_body() {
  local __out="$1" sx="$2" sy="$3" n="$4" mfact="$5"
  local layout
  mosaic_fibonacci_layout_leaf_id=0
  mosaic_fibonacci_layout_node layout "$sx" "$sy" 0 0 "$n" 0 "$mfact"
  printf -v "$__out" '%s' "$layout"
}

mosaic_fibonacci_apply_layout() {
  local win="$1" n="$2" mfact="$3"
  local sx sy body
  sx=$(tmux display-message -p -t "$win" '#{window_width}' 2>/dev/null)
  sy=$(tmux display-message -p -t "$win" '#{window_height}' 2>/dev/null)
  [[ -z "$sx" || -z "$sy" ]] && return 0
  mosaic_fibonacci_layout_body body "$sx" "$sy" "$n" "$mfact"
  tmux select-layout -t "$win" "$(mosaic_fibonacci_layout_checksum "$body"),$body" 2>/dev/null || true
}

mosaic_fibonacci_relayout() {
  local variant win n mfact pbase
  variant=$(mosaic_fibonacci_variant)
  win=$(mosaic_resolve_window "${1:-}")
  n=$(mosaic_window_pane_count "$win")
  mosaic_can_relayout_window "$win" "$n" || return 0
  mfact=$(mosaic_mfact_for "$win")
  pbase=$(mosaic_current_pane_base)

  mosaic_fibonacci_apply_layout "$win" "$n" "$mfact"

  mosaic_log "relayout: win=$win n=$n layout=$variant mfact=$mfact pbase=$pbase"
}

mosaic_fibonacci_promote() {
  local idx n pbase win
  idx=$(mosaic_current_pane_index)
  win=$(mosaic_current_window)
  n=$(mosaic_window_pane_count "$win")
  pbase=$(mosaic_current_pane_base)

  [[ "$n" -le 1 ]] && return 0

  if [[ "$idx" -eq "$pbase" ]]; then
    mosaic_swap_keep_focus -s ":.$pbase" -t ":.$((pbase + 1))"
  else
    mosaic_bubble_keep_focus "$idx" "$pbase"
  fi
  mosaic_fibonacci_relayout
}

mosaic_fibonacci_resize_master() {
  local delta="${1:-}"
  if [[ -z "$delta" ]]; then
    delta=$(mosaic_get "@mosaic-step" "5")
  fi
  local win cur new
  win=$(mosaic_current_window)
  cur=$(mosaic_mfact_for "$win")
  new=$((cur + delta))
  [[ "$new" -lt 5 ]] && new=5
  [[ "$new" -gt 95 ]] && new=95
  tmux set-option -wq -t "$win" "@mosaic-mfact" "$new"
}

mosaic_fibonacci_sync_state() {
  local variant win="$1"
  variant=$(mosaic_fibonacci_variant)
  mosaic_enabled "$win" || return 0
  [[ "$(mosaic_window_zoomed "$win")" == "1" ]] && return 0

  local n
  n=$(mosaic_window_pane_count "$win")
  [[ "$n" -le 1 ]] && return 0

  local pbase pane_size window_size pct
  pbase=$(mosaic_current_pane_base)
  pane_size=$(tmux display-message -p -t "$win.$pbase" '#{pane_width}' 2>/dev/null)
  window_size=$(tmux display-message -p -t "$win" '#{window_width}' 2>/dev/null)
  [[ -z "$pane_size" ]] && return 0
  [[ -z "$window_size" || "$window_size" -le 0 ]] && return 0

  pct=$((pane_size * 100 / window_size))
  [[ "$pct" -lt 5 ]] && pct=5
  [[ "$pct" -gt 95 ]] && pct=95

  mosaic_sync_mfact "$win" "$pct"
  mosaic_log "sync-state: win=$win layout=$variant pbase=$pbase pane_size=$pane_size window_size=$window_size pct=$pct"
}

mosaic_log() {
  local debug
  debug=$(mosaic_get "@mosaic-debug" "0")
  [[ "$debug" != "1" ]] && return 0
  local logfile default_log logdir
  default_log="${TMPDIR:-/tmp}/tmux-mosaic-$(id -u).log"
  logfile=$(mosaic_get "@mosaic-log-file" "$default_log")
  logdir=$(dirname "$logfile")
  mkdir -p "$logdir" 2>/dev/null || true
  printf '%s [%d] %s\n' "$(date +%H:%M:%S.%N)" "$$" "$*" >>"$logfile" 2>/dev/null || true
  return 0
}
