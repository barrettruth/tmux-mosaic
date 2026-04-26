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
  mosaic_t split-window -t "$target" "sleep 3600"
  sleep 0.15
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
