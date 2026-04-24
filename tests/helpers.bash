#!/usr/bin/env bash

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOCKET="${MOSAIC_TEST_SOCKET:-mosaic-test}"

mosaic_t() { tmux -L "$SOCKET" "$@"; }

mosaic_setup_server() {
    mosaic_t kill-server 2>/dev/null || true
    rm -f /tmp/tmux-mosaic-test.log
    local conf="${BATS_TEST_TMPDIR:-/tmp}/mosaic-test.conf"
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

mosaic_enable() {
    mosaic_t set-option -wq -t "${1:-t:1}" "@mosaic-enabled" 1
}

mosaic_split() {
    local target="${1:-t:1}"
    mosaic_t split-window -t "$target" "sleep 3600"
    sleep 0.15
}

mosaic_socket_path() {
    echo "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$SOCKET"
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
