#!/usr/bin/env bash

_mosaic_get() {
  local opt="$1" default="$2"
  local val
  val=$(tmux show-option -gqv "$opt" 2>/dev/null)
  printf '%s\n' "${val:-$default}"
}

_mosaic_get_w() {
  local opt="$1" default="$2" target="${3:-}"
  local val
  if [[ -n "$target" ]]; then
    val=$(tmux show-option -wqvA -t "$target" "$opt" 2>/dev/null)
  else
    val=$(tmux show-option -wqvA "$opt" 2>/dev/null)
  fi
  printf '%s\n' "${val:-$default}"
}

_mosaic_get_gw() {
  local opt="$1" default="$2"
  local val
  val=$(tmux show-option -gwqv "$opt" 2>/dev/null)
  printf '%s\n' "${val:-$default}"
}

_mosaic_get_w_raw() {
  local opt="$1" target="${2:-}"
  local val
  if [[ -n "$target" ]]; then
    val=$(tmux show-option -wqv -t "$target" "$opt" 2>/dev/null)
  else
    val=$(tmux show-option -wqv "$opt" 2>/dev/null)
  fi
  printf '%s\n' "$val"
}

_mosaic_local_layout() {
  local target="${1:-}"
  _mosaic_get_w_raw "@mosaic-layout" "$target"
}

_mosaic_global_layout() {
  _mosaic_get_gw "@mosaic-layout" ""
}

_mosaic_layout_for_window() {
  local target="${1:-}" val
  val=$(_mosaic_local_layout "$target")
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

  val=$(_mosaic_global_layout)
  case "$val" in
  '' | off) printf '\n' ;;
  *) printf '%s\n' "$val" ;;
  esac
}

_mosaic_window_has_local_layout() {
  local target="${1:-}" val
  val=$(_mosaic_local_layout "$target")
  [[ -n "$val" && "$val" != "off" ]]
}

_mosaic_window_has_layout() {
  local target="${1:-}"
  [[ -n "$(_mosaic_layout_for_window "$target")" ]]
}

_mosaic_enabled() {
  local target="${1:-}"
  _mosaic_window_has_layout "$target"
}

_mosaic_auto_apply_for() {
  local target="${1:-}" val
  val=$(_mosaic_get_w "@mosaic-auto-apply" "full" "$target")
  case "$val" in
  full | managed | none)
    printf '%s\n' "$val"
    ;;
  *)
    _mosaic_log "auto-apply: invalid=$val target=$target defaulting=full"
    printf '%s\n' "full"
    ;;
  esac
}

_mosaic_current_window() { tmux display-message -p '#{window_id}'; }

_mosaic_resolve_window() {
  local win="${1:-$(_mosaic_current_window)}"
  printf '%s\n' "$win"
}

_mosaic_window_pane_count() {
  tmux display-message -p -t "$(_mosaic_resolve_window "${1:-}")" '#{window_panes}'
}

_mosaic_window_zoomed() {
  tmux display-message -p -t "$(_mosaic_resolve_window "${1:-}")" '#{window_zoomed_flag}'
}

_mosaic_window_generation_get() {
  _mosaic_get_w_raw "@mosaic-_generation" "${1:-}"
}

_mosaic_window_generation_set() {
  local win="$1" generation="$2"
  tmux set-option -wq -t "$win" "@mosaic-_generation" "$generation"
}

_mosaic_window_generation_unset() {
  tmux set-option -wqu -t "$1" "@mosaic-_generation" 2>/dev/null
}

_mosaic_window_state_get() {
  _mosaic_get_w_raw "@mosaic-_state" "${1:-}"
}

_mosaic_window_state_set() {
  local win="$1" state="$2"
  tmux set-option -wq -t "$win" "@mosaic-_state" "$state"
}

_mosaic_window_state_unset() {
  tmux set-option -wqu -t "$1" "@mosaic-_state" 2>/dev/null
}

_mosaic_pane_owner_generation_get() {
  local pane="$1" val
  val=$(tmux show-option -pqv -t "$pane" "@mosaic-_owner-generation" 2>/dev/null)
  printf '%s\n' "$val"
}

_mosaic_pane_owner_generation_set() {
  local pane="$1" generation="$2"
  tmux set-option -pq -t "$pane" "@mosaic-_owner-generation" "$generation"
}

_mosaic_pane_owner_generation_unset() {
  tmux set-option -pqu -t "$1" "@mosaic-_owner-generation" 2>/dev/null
}

_mosaic_window_panes() {
  tmux list-panes -t "$(_mosaic_resolve_window "${1:-}")" -F '#{pane_id}' 2>/dev/null || true
}

_mosaic_window_generation_new() {
  local win="$1"
  printf '%s\n' "${win}:$(date +%s%N):$$:$RANDOM"
}

_mosaic_window_generation_ensure() {
  local win generation
  win=$(_mosaic_resolve_window "${1:-}")
  generation=$(_mosaic_window_generation_get "$win")
  if [[ -z "$generation" ]]; then
    generation=$(_mosaic_window_generation_new "$win")
    _mosaic_window_generation_set "$win" "$generation"
  fi
  printf '%s\n' "$generation"
}

_mosaic_pane_is_owned_by_window() {
  local pane="$1" win generation owner_generation
  win=$(_mosaic_resolve_window "${2:-}")
  generation=$(_mosaic_window_generation_get "$win")
  [[ -n "$generation" ]] || return 1
  owner_generation=$(_mosaic_pane_owner_generation_get "$pane")
  [[ -n "$owner_generation" && "$owner_generation" == "$generation" ]]
}

_mosaic_window_owned_panes() {
  local win pane
  win=$(_mosaic_resolve_window "${1:-}")
  while IFS= read -r pane; do
    [[ -n "$pane" ]] || continue
    _mosaic_pane_is_owned_by_window "$pane" "$win" && printf '%s\n' "$pane"
  done < <(_mosaic_window_panes "$win")
}

_mosaic_window_foreign_panes() {
  local win pane
  win=$(_mosaic_resolve_window "${1:-}")
  while IFS= read -r pane; do
    [[ -n "$pane" ]] || continue
    _mosaic_pane_is_owned_by_window "$pane" "$win" || printf '%s\n' "$pane"
  done < <(_mosaic_window_panes "$win")
}

_mosaic_window_has_owned_panes() {
  local win pane
  win=$(_mosaic_resolve_window "${1:-}")
  while IFS= read -r pane; do
    [[ -n "$pane" ]] || continue
    return 0
  done < <(_mosaic_window_owned_panes "$win")
  return 1
}

_mosaic_window_has_foreign_panes() {
  local win pane
  win=$(_mosaic_resolve_window "${1:-}")
  while IFS= read -r pane; do
    [[ -n "$pane" ]] || continue
    return 0
  done < <(_mosaic_window_foreign_panes "$win")
  return 1
}

_mosaic_window_adopt_current_panes() {
  local win generation pane
  win=$(_mosaic_resolve_window "${1:-}")
  generation=$(_mosaic_window_generation_ensure "$win")
  while IFS= read -r pane; do
    [[ -n "$pane" ]] || continue
    _mosaic_pane_owner_generation_set "$pane" "$generation"
  done < <(_mosaic_window_panes "$win")
  _mosaic_window_state_set "$win" "managed"
}

_mosaic_window_refresh_state() {
  local win
  win=$(_mosaic_resolve_window "${1:-}")
  if _mosaic_window_has_foreign_panes "$win"; then
    _mosaic_window_state_set "$win" "suspended"
  elif _mosaic_window_has_owned_panes "$win"; then
    _mosaic_window_state_set "$win" "managed"
  else
    _mosaic_window_state_unset "$win"
  fi
}

_mosaic_window_bootstrap_ownership() {
  local win pane_count
  win=$(_mosaic_resolve_window "${1:-}")
  _mosaic_window_has_layout "$win" || return 0
  [[ -z "$(_mosaic_window_generation_get "$win")" ]] || return 0
  pane_count=$(_mosaic_window_pane_count "$win")
  [[ "$pane_count" -ge 1 ]] || return 0
  _mosaic_window_adopt_current_panes "$win"
}

_mosaic_window_ownership_clear() {
  local win pane
  win=$(_mosaic_resolve_window "${1:-}")
  while IFS= read -r pane; do
    [[ -n "$pane" ]] || continue
    _mosaic_pane_owner_generation_unset "$pane"
  done < <(_mosaic_window_panes "$win")
  _mosaic_window_state_unset "$win"
  _mosaic_window_generation_unset "$win"
}

_mosaic_nmaster_for() {
  local target="${1:-}" val
  val=$(_mosaic_get_w "@mosaic-nmaster" "1" "$target")
  [[ "$val" =~ ^[1-9][0-9]*$ ]] || {
    _mosaic_log "nmaster: invalid=$val target=$target defaulting=1"
    val=1
  }
  printf '%s\n' "$val"
}

_mosaic_effective_nmaster() {
  local target="${1:-}" n="${2:-}" val
  [[ -n "$n" ]] || n=$(_mosaic_window_pane_count "$target")
  val=$(_mosaic_nmaster_for "$target")
  [[ "$val" -gt "$n" ]] && val=$n
  printf '%s\n' "$val"
}

_mosaic_first_client() {
  tmux list-clients -F '#{client_name}' 2>/dev/null | head -n1
}

_mosaic_mfact_for() {
  local win="$1" val
  val=$(tmux show-option -wqvA -t "$win" "@mosaic-mfact" 2>/dev/null)
  [[ -n "$val" ]] && {
    printf '%s\n' "$val"
    return
  }
  _mosaic_get "@mosaic-mfact" "50"
}

_mosaic_compute_fingerprint() {
  local win="$1" layout="$2"
  local n mfact nmaster orientation window_w window_h zoomed
  n=$(_mosaic_window_pane_count "$win")
  mfact=$(_mosaic_get_w "@mosaic-mfact" "50" "$win")
  nmaster=$(_mosaic_get_w "@mosaic-nmaster" "1" "$win")
  orientation=$(_mosaic_get_w "@mosaic-orientation" "left" "$win")
  window_w=$(tmux display-message -p -t "$win" '#{window_width}' 2>/dev/null)
  window_h=$(tmux display-message -p -t "$win" '#{window_height}' 2>/dev/null)
  zoomed=$(_mosaic_window_zoomed "$win")
  printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
    "$layout" "$n" "$mfact" "$nmaster" "$orientation" "$window_w" "$window_h" "$zoomed"
}

_mosaic_fingerprint_get() {
  _mosaic_get_w_raw "@mosaic-_fingerprint" "${1:-}"
}

_mosaic_pending_fingerprint_get() {
  _mosaic_get_w_raw "@mosaic-_pending-fingerprint" "${1:-}"
}

_mosaic_fingerprint_set() {
  local win="$1" fp="$2"
  tmux set-option -wq -t "$win" "@mosaic-_fingerprint" "$fp"
}

_mosaic_fingerprint_unset() {
  tmux set-option -wqu -t "$1" "@mosaic-_fingerprint" 2>/dev/null
}

_mosaic_pending_fingerprint_set() {
  local win="$1" fp="$2"
  tmux set-option -wq -t "$win" "@mosaic-_pending-fingerprint" "$fp"
}

_mosaic_pending_fingerprint_unset() {
  tmux set-option -wqu -t "$1" "@mosaic-_pending-fingerprint" 2>/dev/null
}

_mosaic_sync_mfact() {
  local win="$1" pct="$2" current
  current=$(_mosaic_get_w_raw "@mosaic-mfact" "$win")
  [[ "$current" == "$pct" ]] && return 0
  tmux set-option -wq -t "$win" "@mosaic-mfact" "$pct"
}

_mosaic_show_message() {
  local message="$*" client
  client=$(tmux display-message -p '#{client_name}' 2>/dev/null)
  [[ -z "$client" ]] && client=$(_mosaic_first_client)
  if [[ -n "$client" ]]; then
    tmux display-message -c "$client" "$message"
  else
    printf '%s\n' "$message" >&2
  fi
}

_mosaic_can_relayout_window() {
  local win="$1" n="$2"
  if ! _mosaic_enabled "$win"; then
    _mosaic_log "relayout: disabled on $win, skipping"
    return 1
  fi
  [[ "$n" -gt 1 ]]
}

_mosaic_toggle_window() {
  local win local_layout global_layout
  win=$(_mosaic_current_window)
  local_layout=$(_mosaic_local_layout "$win")
  global_layout=$(_mosaic_global_layout)

  if [[ "$local_layout" == "off" ]]; then
    if [[ -n "$global_layout" && "$global_layout" != "off" ]]; then
      tmux set-option -wqu -t "$win" "@mosaic-layout" 2>/dev/null
      _mosaic_show_message "mosaic: on"
    else
      _mosaic_show_message "mosaic: no layout configured"
    fi
  elif [[ -n "$local_layout" ]]; then
    if [[ -n "$global_layout" && "$global_layout" != "off" ]]; then
      tmux set-option -wq -t "$win" "@mosaic-layout" "off"
    else
      tmux set-option -wqu -t "$win" "@mosaic-layout" 2>/dev/null
    fi
    _mosaic_show_message "mosaic: off"
  elif [[ -n "$global_layout" && "$global_layout" != "off" ]]; then
    tmux set-option -wq -t "$win" "@mosaic-layout" "off"
    _mosaic_show_message "mosaic: off"
  else
    _mosaic_show_message "mosaic: no layout configured"
  fi
}

_mosaic_relayout_simple() {
  local layout="$1" win n
  win=$(_mosaic_resolve_window "${2:-}")
  n=$(_mosaic_window_pane_count "$win")
  _mosaic_can_relayout_window "$win" "$n" || return 0
  tmux select-layout -t "$win" "$layout" 2>/dev/null || true
  _mosaic_log "relayout: win=$win n=$n layout=$layout"
}

_mosaic_current_pane_index() { tmux display-message -p '#{pane_index}'; }

_mosaic_current_pane_base() {
  tmux display-message -p '#{e|+|:0,#{?pane-base-index,#{pane-base-index},0}}'
}

_mosaic_swap_keep_focus() {
  local pid
  pid=$(tmux display-message -p '#{pane_id}')
  tmux swap-pane "$@"
  tmux select-pane -t "$pid"
}

_mosaic_bubble_keep_focus() {
  local from="$1" to="$2"
  while [[ "$from" -gt "$to" ]]; do
    _mosaic_swap_keep_focus -s ":.$from" -t ":.$((from - 1))"
    from=$((from - 1))
  done
  while [[ "$from" -lt "$to" ]]; do
    _mosaic_swap_keep_focus -s ":.$from" -t ":.$((from + 1))"
    from=$((from + 1))
  done
}

_mosaic_fibonacci_variant() {
  if declare -f _layout_fibonacci_variant >/dev/null 2>&1; then
    _layout_fibonacci_variant
  else
    printf '%s\n' "spiral"
  fi
}

_mosaic_fibonacci_layout_checksum() {
  local layout="$1" csum=0 i ch
  for ((i = 0; i < ${#layout}; i++)); do
    printf -v ch '%d' "'${layout:i:1}"
    csum=$(((csum >> 1) | ((csum & 1) << 15)))
    csum=$(((csum + ch) & 0xffff))
  done
  printf '%04x\n' "$csum"
}

_mosaic_fibonacci_layout_leaf_id=0

_mosaic_fibonacci_layout_leaf() {
  local __out="$1" sx="$2" sy="$3" x="$4" y="$5" id="$_mosaic_fibonacci_layout_leaf_id"
  _mosaic_fibonacci_layout_leaf_id=$((_mosaic_fibonacci_layout_leaf_id + 1))
  printf -v "$__out" '%sx%s,%s,%s,%s' "$sx" "$sy" "$x" "$y" "$id"
}

_mosaic_fibonacci_layout_split_master() {
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

_mosaic_fibonacci_layout_split_half() {
  local __first="$1" __second="$2" total="$3"
  local usable first second
  usable=$((total - 1))
  first=$(((usable + 1) / 2))
  second=$((usable - first))
  printf -v "$__first" '%s' "$first"
  printf -v "$__second" '%s' "$second"
}

_mosaic_fibonacci_layout_step() {
  local __split="$1" __order="$2" __next="$3" step="$4"
  local variant value_split value_order value_next
  variant=$(_mosaic_fibonacci_variant)
  case "$variant:$step" in
  spiral:0 | dwindle:0)
    value_split="master"
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

_mosaic_fibonacci_layout_node() {
  local __out="$1" sx="$2" sy="$3" x="$4" y="$5" n="$6" step="$7" mfact="$8"
  local split order next axis container
  local node_a_var="${__out}_a" node_b_var="${__out}_b" first_size second_size

  if [[ "$n" -eq 1 ]]; then
    _mosaic_fibonacci_layout_leaf "$__out" "$sx" "$sy" "$x" "$y"
    return
  fi

  _mosaic_fibonacci_layout_step split order next "$step"
  case "$split" in
  master)
    _mosaic_fibonacci_layout_split_master first_size second_size "$sx" "$mfact"
    axis="x"
    container="{}"
    ;;
  x)
    _mosaic_fibonacci_layout_split_half first_size second_size "$sx"
    axis="x"
    container="{}"
    ;;
  y)
    _mosaic_fibonacci_layout_split_half first_size second_size "$sy"
    axis="y"
    container="[]"
    ;;
  esac

  if [[ "$axis" == "x" ]]; then
    if [[ "$order" == "leaf-node" ]]; then
      _mosaic_fibonacci_layout_leaf "$node_a_var" "$first_size" "$sy" "$x" "$y"
      _mosaic_fibonacci_layout_node "$node_b_var" "$second_size" "$sy" "$((x + first_size + 1))" "$y" "$((n - 1))" "$next" "$mfact"
    else
      _mosaic_fibonacci_layout_node "$node_a_var" "$first_size" "$sy" "$x" "$y" "$((n - 1))" "$next" "$mfact"
      _mosaic_fibonacci_layout_leaf "$node_b_var" "$second_size" "$sy" "$((x + first_size + 1))" "$y"
    fi
  else
    if [[ "$order" == "leaf-node" ]]; then
      _mosaic_fibonacci_layout_leaf "$node_a_var" "$sx" "$first_size" "$x" "$y"
      _mosaic_fibonacci_layout_node "$node_b_var" "$sx" "$second_size" "$x" "$((y + first_size + 1))" "$((n - 1))" "$next" "$mfact"
    else
      _mosaic_fibonacci_layout_node "$node_a_var" "$sx" "$first_size" "$x" "$y" "$((n - 1))" "$next" "$mfact"
      _mosaic_fibonacci_layout_leaf "$node_b_var" "$sx" "$second_size" "$x" "$((y + first_size + 1))"
    fi
  fi

  if [[ "$container" == "{}" ]]; then
    printf -v "$__out" '%sx%s,%s,%s{%s,%s}' "$sx" "$sy" "$x" "$y" "${!node_a_var}" "${!node_b_var}"
  else
    printf -v "$__out" '%sx%s,%s,%s[%s,%s]' "$sx" "$sy" "$x" "$y" "${!node_a_var}" "${!node_b_var}"
  fi
}

_mosaic_fibonacci_layout_body() {
  local __out="$1" sx="$2" sy="$3" n="$4" mfact="$5"
  local layout
  _mosaic_fibonacci_layout_leaf_id=0
  _mosaic_fibonacci_layout_node layout "$sx" "$sy" 0 0 "$n" 0 "$mfact"
  printf -v "$__out" '%s' "$layout"
}

_mosaic_fibonacci_apply_layout() {
  local win="$1" n="$2" mfact="$3"
  local sx sy body
  sx=$(tmux display-message -p -t "$win" '#{window_width}' 2>/dev/null)
  sy=$(tmux display-message -p -t "$win" '#{window_height}' 2>/dev/null)
  [[ -z "$sx" || -z "$sy" ]] && return 0
  _mosaic_fibonacci_layout_body body "$sx" "$sy" "$n" "$mfact"
  tmux select-layout -t "$win" "$(_mosaic_fibonacci_layout_checksum "$body"),$body" 2>/dev/null || true
}

_mosaic_fibonacci_relayout() {
  local variant win n mfact pbase
  variant=$(_mosaic_fibonacci_variant)
  win=$(_mosaic_resolve_window "${1:-}")
  n=$(_mosaic_window_pane_count "$win")
  _mosaic_can_relayout_window "$win" "$n" || return 0
  mfact=$(_mosaic_mfact_for "$win")
  pbase=$(_mosaic_current_pane_base)

  _mosaic_fibonacci_apply_layout "$win" "$n" "$mfact"

  _mosaic_log "relayout: win=$win n=$n layout=$variant mfact=$mfact pbase=$pbase"
}

_mosaic_fibonacci_promote() {
  local idx n pbase win
  idx=$(_mosaic_current_pane_index)
  win=$(_mosaic_current_window)
  n=$(_mosaic_window_pane_count "$win")
  pbase=$(_mosaic_current_pane_base)

  [[ "$n" -le 1 ]] && return 0

  if [[ "$idx" -eq "$pbase" ]]; then
    _mosaic_swap_keep_focus -s ":.$pbase" -t ":.$((pbase + 1))"
  else
    _mosaic_bubble_keep_focus "$idx" "$pbase"
  fi
  _mosaic_fibonacci_relayout
}

_mosaic_fibonacci_resize_master() {
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

_mosaic_fibonacci_sync_state() {
  local variant win="$1"
  variant=$(_mosaic_fibonacci_variant)
  _mosaic_enabled "$win" || return 0
  [[ "$(_mosaic_window_zoomed "$win")" == "1" ]] && return 0

  local n
  n=$(_mosaic_window_pane_count "$win")
  [[ "$n" -le 1 ]] && return 0

  local pbase pane_size window_size pct
  pbase=$(_mosaic_current_pane_base)
  pane_size=$(tmux display-message -p -t "$win.$pbase" '#{pane_width}' 2>/dev/null)
  window_size=$(tmux display-message -p -t "$win" '#{window_width}' 2>/dev/null)
  [[ -z "$pane_size" ]] && return 0
  [[ -z "$window_size" || "$window_size" -le 0 ]] && return 0

  pct=$((pane_size * 100 / window_size))
  [[ "$pct" -lt 5 ]] && pct=5
  [[ "$pct" -gt 95 ]] && pct=95

  _mosaic_sync_mfact "$win" "$pct"
  _mosaic_log "sync-state: win=$win layout=$variant pbase=$pbase pane_size=$pane_size window_size=$window_size pct=$pct"
}

_mosaic_log() {
  local debug
  debug=$(_mosaic_get "@mosaic-debug" "0")
  [[ "$debug" != "1" ]] && return 0
  local logfile default_log logdir
  default_log="${TMPDIR:-/tmp}/tmux-mosaic-$(id -u).log"
  logfile=$(_mosaic_get "@mosaic-log-file" "$default_log")
  logdir=$(dirname "$logfile")
  mkdir -p "$logdir" 2>/dev/null || true
  printf '%s [%d] %s\n' "$(date +%H:%M:%S.%N)" "$$" "$*" >>"$logfile" 2>/dev/null || true
  return 0
}
