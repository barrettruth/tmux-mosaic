#!/usr/bin/env bash

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mosaic_socket() {
  echo "${MOSAIC_TEST_SOCKET:-mosaic-test}-${BATS_TEST_NUMBER:-0}"
}

mosaic_t() { tmux -L "$(mosaic_socket)" "$@"; }

mosaic_setup_server() {
  mosaic_t kill-server 2>/dev/null || true
  rm -f /tmp/tmux-mosaic-test.log
  local conf
  conf="${BATS_TEST_TMPDIR:-/tmp}/$(mosaic_socket).conf"
  cat >"$conf" <<EOF
set -g base-index 1
set -g pane-base-index 1
set -g default-terminal "screen-256color"
run-shell "$REPO_ROOT/mosaic.tmux"
set-option -gq @mosaic-debug 1
set-option -gq @mosaic-log-file "/tmp/tmux-mosaic-test.log"
EOF
  mosaic_t -f "$conf" new-session -d -s t -x 200 -y 50 "sleep 3600"
  sleep 0.05
}

mosaic_teardown_server() {
  mosaic_t kill-server 2>/dev/null || true
}

mosaic_use_algorithm() {
  local algo="${1:?algorithm required}" target="${2:-t:1}"
  mosaic_t set-option -wq -t "$target" "@mosaic-algorithm" "$algo"
}

mosaic_use_global_algorithm() {
  local algo="${1:?algorithm required}"
  mosaic_t set-option -gwq "@mosaic-algorithm" "$algo"
}

mosaic_disable_algorithm() {
  local target="${1:-t:1}"
  mosaic_t set-option -wq -t "$target" "@mosaic-algorithm" "off"
}

mosaic_clear_algorithm() {
  local target="${1:-t:1}"
  mosaic_t set-option -wqu -t "$target" "@mosaic-algorithm"
}

mosaic_split() {
  local target="${1:-t:1}"
  local before
  before=$(mosaic_t display-message -p -t "$target" '#{window_panes}' 2>/dev/null || echo 0)
  mosaic_t split-window -t "$target" "sleep 3600"
  mosaic_wait_pane_count_gt "$before" "$target"
  mosaic_quiesce
}

mosaic_socket_path() {
  echo "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$(mosaic_socket)"
}

mosaic_exec_direct() {
  local exec sock
  exec=$(mosaic_t show-option -gqv "@mosaic-exec")
  sock=$(mosaic_socket_path)
  TMUX="$sock,$$,0" "$exec" "$@"
}

mosaic_pane_id_at() {
  mosaic_t display-message -p -t "${1:?index required}" '#{pane_id}'
}

mosaic_pane_index() {
  mosaic_t display-message -p -t "${1:-t:1}" '#{pane_index}'
}

mosaic_pane_count() {
  mosaic_t display-message -p -t "${1:-t:1}" '#{window_panes}'
}

mosaic_layout() {
  mosaic_t display-message -p -t "${1:-t:1}" '#{window_layout}' | cut -d, -f2-
}

mosaic_op() {
  local exec
  exec=$(mosaic_t show-option -gqv "@mosaic-exec")
  mosaic_t run-shell "$exec $*"
}

mosaic_panes_summary() {
  mosaic_t list-panes -t "${1:-t:1}" -F '#{pane_index}:#{pane_id}' | paste -sd' '
}

mosaic_layout_outer() {
  mosaic_layout "${1:-t:1}" | awk 'match($0, /[\[{]/) { print substr($0, RSTART, 1); exit }'
}

mosaic_log_relayout_count() {
  local n
  n=$(grep -c '^[^ ]* \[[0-9]*\] relayout:' /tmp/tmux-mosaic-test.log 2>/dev/null) || n=0
  printf '%s\n' "$n"
}

mosaic_log_sync_count() {
  local n
  n=$(grep -c '^[^ ]* \[[0-9]*\] sync-state:' /tmp/tmux-mosaic-test.log 2>/dev/null) || n=0
  printf '%s\n' "$n"
}

mosaic_quiesce() {
  sleep 0.1
}

mosaic_wait_until() {
  local timeout_ms="${1:-2000}"
  shift
  local elapsed=0
  while ! "$@" >/dev/null 2>&1; do
    sleep 0.02
    elapsed=$((elapsed + 20))
    [[ "$elapsed" -ge "$timeout_ms" ]] && return 1
  done
  return 0
}

mosaic_wait_log_quiet() {
  local timeout_ms="${1:-1000}" stable_ms="${2:-100}"
  local elapsed=0 stable_for=0 prev current
  prev=$(wc -l </tmp/tmux-mosaic-test.log 2>/dev/null || echo 0)
  while [[ "$elapsed" -lt "$timeout_ms" ]]; do
    sleep 0.05
    elapsed=$((elapsed + 50))
    current=$(wc -l </tmp/tmux-mosaic-test.log 2>/dev/null || echo 0)
    if [[ "$current" == "$prev" ]]; then
      stable_for=$((stable_for + 50))
      [[ "$stable_for" -ge "$stable_ms" ]] && return 0
    else
      stable_for=0
      prev="$current"
    fi
  done
  return 0
}

mosaic_reset_log() {
  mosaic_wait_log_quiet 600 100
  : >/tmp/tmux-mosaic-test.log
}

mosaic_wait_relayout_count_ge() {
  local expected="${1:?expected count required}" timeout="${2:-1500}"
  mosaic_wait_until "$timeout" bash -c "
    n=\$(grep -c '^[^ ]* \[[0-9]*\] relayout:' /tmp/tmux-mosaic-test.log 2>/dev/null) || n=0
    [ \"\$n\" -ge \"$expected\" ]"
}

mosaic_wait_log_match() {
  local pattern="${1:?pattern required}" timeout="${2:-1500}"
  mosaic_wait_until "$timeout" grep -q "$pattern" /tmp/tmux-mosaic-test.log
}

mosaic_wait_option() {
  local opt="${1:?opt required}" expected="${2-}" target="${3:-t:1}" timeout="${4:-1500}"
  mosaic_wait_until "$timeout" \
    bash -c "[ \"\$(tmux -L $(mosaic_socket) show-option -wqv -t '$target' '$opt' 2>/dev/null)\" = \"$expected\" ]"
}

mosaic_wait_option_empty() {
  mosaic_wait_option "${1:?opt required}" "" "${2:-t:1}" "${3:-1500}"
}

mosaic_wait_option_set() {
  local opt="${1:?opt required}" target="${2:-t:1}" timeout="${3:-1500}"
  mosaic_wait_until "$timeout" \
    bash -c "[ -n \"\$(tmux -L $(mosaic_socket) show-option -wqv -t '$target' '$opt' 2>/dev/null)\" ]"
}

mosaic_wait_option_changed_from() {
  local opt="${1:?opt required}" old="${2:?old value required}" target="${3:-t:1}" timeout="${4:-1500}"
  mosaic_wait_until "$timeout" \
    bash -c "v=\$(tmux -L $(mosaic_socket) show-option -wqv -t '$target' '$opt' 2>/dev/null); [ -n \"\$v\" ] && [ \"\$v\" != \"$old\" ]"
}

mosaic_fingerprint() {
  mosaic_t show-option -wqv -t "${1:-t:1}" "@mosaic-_fingerprint" 2>/dev/null
}

mosaic_wait_fingerprint_changed_from() {
  local old="${1-}" target="${2:-t:1}" timeout="${3:-1500}"
  mosaic_wait_until "$timeout" \
    bash -c "v=\$(tmux -L $(mosaic_socket) show-option -wqv -t '$target' '@mosaic-_fingerprint' 2>/dev/null); [ \"\$v\" != \"$old\" ]"
}

mosaic_wait_pane_count() {
  local expected="${1:?expected required}" target="${2:-t:1}" timeout="${3:-1500}"
  mosaic_wait_until "$timeout" \
    bash -c "[ \"\$(tmux -L $(mosaic_socket) display-message -p -t '$target' '#{window_panes}' 2>/dev/null)\" = '$expected' ]"
}

mosaic_wait_pane_count_gt() {
  local min="${1:?min required}" target="${2:-t:1}" timeout="${3:-1500}"
  mosaic_wait_until "$timeout" \
    bash -c "[ \"\$(tmux -L $(mosaic_socket) display-message -p -t '$target' '#{window_panes}' 2>/dev/null || echo 0)\" -gt $min ]"
}

mosaic_wait_pane_left_gt() {
  local idx="${1:?idx required}" min="${2:?min required}" target="${3:-t:1}" timeout="${4:-1500}"
  mosaic_wait_until "$timeout" \
    bash -c "[ \"\$(tmux -L $(mosaic_socket) list-panes -t '$target' -F '#{pane_index} #{pane_left}' | awk -v i=$idx '\$1 == i { print \$2 }')\" -gt \"$min\" ]"
}

mosaic_wait_layout_outer() {
  local expected="${1:?[ or { required}" target="${2:-t:1}" timeout="${3:-1500}"
  mosaic_wait_until "$timeout" \
    bash -c "[ \"\$(tmux -L $(mosaic_socket) display-message -p -t '$target' '#{window_layout}' | cut -d, -f2- | awk 'match(\$0, /[\\[{]/) { print substr(\$0, RSTART, 1); exit }')\" = '$expected' ]"
}

mosaic_wait_window_zoomed() {
  local expected="${1:?0 or 1 required}" target="${2:-t:1}" timeout="${3:-1500}"
  mosaic_wait_until "$timeout" \
    bash -c "[ \"\$(tmux -L $(mosaic_socket) display-message -p -t '$target' '#{window_zoomed_flag}' 2>/dev/null)\" = '$expected' ]"
}
