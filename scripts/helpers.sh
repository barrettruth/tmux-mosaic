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
    val=$(tmux show-option -wqv -t "$target" "$opt" 2>/dev/null)
  else
    val=$(tmux show-option -wqv "$opt" 2>/dev/null)
  fi
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

mosaic_window_has_algorithm() {
  local target="${1:-}"
  [[ -n "$(mosaic_get_w_raw "@mosaic-algorithm" "$target")" ]]
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

mosaic_first_client() {
  tmux list-clients -F '#{client_name}' 2>/dev/null | head -n1
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
  local _relayout_fn="${1:-}" win
  win=$(mosaic_current_window)
  if mosaic_window_has_algorithm "$win"; then
    tmux set-option -wqu -t "$win" "@mosaic-algorithm" 2>/dev/null
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

mosaic_log() {
  local debug
  debug=$(mosaic_get "@mosaic-debug" "0")
  [[ "$debug" != "1" ]] && return 0
  local logfile default_log
  default_log="${TMPDIR:-/tmp}/tmux-mosaic-$(id -u).log"
  logfile=$(mosaic_get "@mosaic-log-file" "$default_log")
  printf '%s [%d] %s\n' "$(date +%H:%M:%S.%N)" "$$" "$*" >>"$logfile"
}
