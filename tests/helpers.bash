#!/usr/bin/env bash

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

_mosaic_test_id() {
  printf '%s\n' "${BATS_TEST_FILENAME:-}:${BATS_TEST_NAME:-}:${BATS_SUITE_TEST_NUMBER:-${BATS_TEST_NUMBER:-0}}" | cksum | awk '{print $1}'
}

_mosaic_test_instance_id() {
  if [[ -n "${BATS_TEST_TMPDIR:-}" ]]; then
    printf '%s\n' "$BATS_TEST_TMPDIR" | cksum | awk '{print $1}'
  else
    _mosaic_test_id
  fi
}

_mosaic_socket() {
  echo "${MOSAIC_TEST_SOCKET:-mosaic-test}-$(_mosaic_test_instance_id)"
}

_mosaic_t() { tmux -L "$(_mosaic_socket)" "$@"; }

_mosaic_test_tmpdir() {
  if [[ -n "${BATS_TEST_TMPDIR:-}" ]]; then
    printf '%s\n' "$BATS_TEST_TMPDIR"
  else
    echo "${TMPDIR:-/tmp}/tmux-mosaic-tests/$(_mosaic_test_id)"
  fi
}

_mosaic_log_file() {
  echo "$(_mosaic_test_tmpdir)/tmux-mosaic-test.log"
}

_mosaic_setup_server() {
  _mosaic_t kill-server 2>/dev/null || true
  mkdir -p "$(_mosaic_test_tmpdir)"
  rm -f "$(_mosaic_log_file)"
  local conf
  conf="$(_mosaic_test_tmpdir)/$(_mosaic_socket).conf"
  cat >"$conf" <<EOF
set -g base-index 1
set -g pane-base-index 1
set -g default-terminal "screen-256color"
run-shell "$REPO_ROOT/mosaic.tmux"
set-option -gq @mosaic-debug 1
set-option -gq @mosaic-log-file "$(_mosaic_log_file)"
EOF
  _mosaic_t -f "$conf" new-session -d -s t -x 200 -y 50 "sleep 3600"
  _mosaic_wait_until 3000 \
    bash -c "[ -n \"\$(tmux -L $(_mosaic_socket) show-option -gqv '@mosaic-exec' 2>/dev/null)\" ]"
}

_mosaic_teardown_server() {
  _mosaic_t kill-server 2>/dev/null || true
}

_mosaic_use_layout() {
  local layout="${1:?layout required}" target="${2:-t:1}"
  _mosaic_t set-option -wq -t "$target" "@mosaic-layout" "$layout"
}

_mosaic_use_global_layout() {
  local layout="${1:?layout required}"
  _mosaic_t set-option -gwq "@mosaic-layout" "$layout"
}

_mosaic_disable_layout() {
  local target="${1:-t:1}"
  _mosaic_t set-option -wq -t "$target" "@mosaic-layout" "off"
}

_mosaic_clear_layout() {
  local target="${1:-t:1}"
  _mosaic_t set-option -wqu -t "$target" "@mosaic-layout"
}

_mosaic_split() {
  local target="${1:-t:1}" before fp layout
  _mosaic_quiesce
  before=$(_mosaic_t display-message -p -t "$target" '#{window_panes}' 2>/dev/null || echo 0)
  fp=$(_mosaic_fingerprint "$target")
  layout=$(_mosaic_t show-option -wqvA -t "$target" "@mosaic-layout" 2>/dev/null)
  _mosaic_t split-window -t "$target" "sleep 3600"
  _mosaic_wait_pane_count_gt "$before" "$target"
  if [[ -n "$layout" && "$layout" != "off" ]]; then
    if [[ -n "$fp" ]]; then
      _mosaic_wait_fingerprint_changed_from "$fp" "$target"
    else
      _mosaic_wait_option_set "@mosaic-_fingerprint" "$target"
    fi
  fi
  _mosaic_quiesce
}

_mosaic_socket_path() {
  echo "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$(_mosaic_socket)"
}

_mosaic_exec_direct() {
  local exec sock
  exec=$(_mosaic_t show-option -gqv "@mosaic-exec")
  sock=$(_mosaic_socket_path)
  TMUX="$sock,$$,0" "$exec" "$@"
}

_mosaic_pane_id_at() {
  _mosaic_t display-message -p -t "${1:?index required}" '#{pane_id}'
}

_mosaic_pane_current_path() {
  _mosaic_t display-message -p -t "${1:?target required}" '#{pane_current_path}'
}

_mosaic_pane_index() {
  _mosaic_t display-message -p -t "${1:-t:1}" '#{pane_index}'
}

_mosaic_pane_count() {
  _mosaic_t display-message -p -t "${1:-t:1}" '#{window_panes}'
}

_mosaic_layout() {
  _mosaic_t display-message -p -t "${1:-t:1}" '#{window_layout}' | cut -d, -f2-
}

_mosaic_window_generation() {
  _mosaic_t show-option -wqv -t "${1:-t:1}" "@mosaic-_generation" 2>/dev/null
}

_mosaic_window_state() {
  _mosaic_t show-option -wqv -t "${1:-t:1}" "@mosaic-_state" 2>/dev/null
}

_mosaic_pane_owner_generation() {
  _mosaic_t show-option -pqv -t "${1:?pane required}" "@mosaic-_owner-generation" 2>/dev/null
}

_mosaic_op() {
  local exec
  exec=$(_mosaic_t show-option -gqv "@mosaic-exec")
  _mosaic_t run-shell "$exec $*"
}

_mosaic_panes_summary() {
  _mosaic_t list-panes -t "${1:-t:1}" -F '#{pane_index}:#{pane_id}' | paste -sd' '
}

_mosaic_layout_outer() {
  _mosaic_layout "${1:-t:1}" | awk 'match($0, /[\[{]/) { print substr($0, RSTART, 1); exit }'
}

_mosaic_log_relayout_count() {
  local n
  n=$(grep -c '^[^ ]* \[[0-9]*\] relayout:' "$(_mosaic_log_file)" 2>/dev/null) || n=0
  printf '%s\n' "$n"
}

_mosaic_log_sync_count() {
  local n
  n=$(grep -c '^[^ ]* \[[0-9]*\] sync-state:' "$(_mosaic_log_file)" 2>/dev/null) || n=0
  printf '%s\n' "$n"
}

_mosaic_log_line_count() {
  local log
  log=$(_mosaic_log_file)
  [[ -f "$log" ]] || {
    printf '0\n'
    return 0
  }
  wc -l <"$log"
}

_mosaic_quiesce() {
  _mosaic_wait_log_quiet 1500 100
}

_mosaic_wait_until() {
  local timeout_ms="${1:-3000}"
  shift
  local elapsed=0
  while ! "$@" >/dev/null 2>&1; do
    sleep 0.02
    elapsed=$((elapsed + 20))
    [[ "$elapsed" -ge "$timeout_ms" ]] && return 1
  done
  return 0
}

_mosaic_wait_log_quiet() {
  local timeout_ms="${1:-1000}" stable_ms="${2:-100}"
  local elapsed=0 stable_for=0 prev current
  prev=$(_mosaic_log_line_count)
  while [[ "$elapsed" -lt "$timeout_ms" ]]; do
    sleep 0.05
    elapsed=$((elapsed + 50))
    current=$(_mosaic_log_line_count)
    if [[ "$current" == "$prev" ]]; then
      stable_for=$((stable_for + 50))
      [[ "$stable_for" -ge "$stable_ms" ]] && return 0
    else
      stable_for=0
      prev="$current"
    fi
  done
  return 1
}

_mosaic_reset_log() {
  _mosaic_quiesce
  : >"$(_mosaic_log_file)"
}

_mosaic_wait_relayout_count_ge() {
  local expected="${1:?expected count required}" timeout="${2:-3000}" log
  log=$(_mosaic_log_file)
  _mosaic_wait_until "$timeout" bash -c "
    n=\$(grep -c '^[^ ]* \[[0-9]*\] relayout:' '$log' 2>/dev/null) || n=0
    [ \"\$n\" -ge \"$expected\" ]"
}

_mosaic_wait_log_match() {
  local pattern="${1:?pattern required}" timeout="${2:-3000}"
  _mosaic_wait_until "$timeout" grep -q "$pattern" "$(_mosaic_log_file)"
}

_mosaic_wait_option() {
  local opt="${1:?opt required}" expected="${2-}" target="${3:-t:1}" timeout="${4:-3000}"
  _mosaic_wait_until "$timeout" \
    bash -c "[ \"\$(tmux -L $(_mosaic_socket) show-option -wqv -t '$target' '$opt' 2>/dev/null)\" = \"$expected\" ]"
}

_mosaic_wait_option_empty() {
  _mosaic_wait_option "${1:?opt required}" "" "${2:-t:1}" "${3:-3000}"
}

_mosaic_wait_option_set() {
  local opt="${1:?opt required}" target="${2:-t:1}" timeout="${3:-3000}"
  _mosaic_wait_until "$timeout" \
    bash -c "[ -n \"\$(tmux -L $(_mosaic_socket) show-option -wqv -t '$target' '$opt' 2>/dev/null)\" ]"
}

_mosaic_wait_window_generation_set() {
  local target="${1:-t:1}" timeout="${2:-3000}"
  _mosaic_wait_until "$timeout" \
    bash -c "[ -n \"\$(tmux -L $(_mosaic_socket) show-option -wqv -t '$target' '@mosaic-_generation' 2>/dev/null)\" ]"
}

_mosaic_wait_window_generation_empty() {
  local target="${1:-t:1}" timeout="${2:-3000}"
  _mosaic_wait_until "$timeout" \
    bash -c "[ -z \"\$(tmux -L $(_mosaic_socket) show-option -wqv -t '$target' '@mosaic-_generation' 2>/dev/null)\" ]"
}

_mosaic_wait_window_state() {
  local expected="${1-}" target="${2:-t:1}" timeout="${3:-3000}"
  _mosaic_wait_until "$timeout" \
    bash -c "[ \"\$(tmux -L $(_mosaic_socket) show-option -wqv -t '$target' '@mosaic-_state' 2>/dev/null)\" = \"$expected\" ]"
}

_mosaic_wait_window_ownership_cleared() {
  local target="${1:-t:1}" timeout="${2:-3000}" stable_ms="${3:-100}"
  local elapsed=0 stable_for=0 ok pane
  while [[ "$elapsed" -lt "$timeout" ]]; do
    sleep 0.02
    elapsed=$((elapsed + 20))
    ok=1
    [[ -z "$(_mosaic_window_generation "$target")" ]] || ok=0
    [[ -z "$(_mosaic_window_state "$target")" ]] || ok=0
    if [[ "$ok" == "1" ]]; then
      while IFS= read -r pane; do
        [[ -n "$pane" ]] || continue
        if [[ -n "$(_mosaic_pane_owner_generation "$pane")" ]]; then
          ok=0
          break
        fi
      done < <(_mosaic_t list-panes -t "$target" -F '#{pane_id}')
    fi
    if [[ "$ok" == "1" ]]; then
      stable_for=$((stable_for + 20))
      [[ "$stable_for" -ge "$stable_ms" ]] && return 0
    else
      stable_for=0
    fi
  done
  return 1
}

_mosaic_wait_pane_owner_generation() {
  local pane="${1:?pane required}" expected="${2-}" timeout="${3:-3000}"
  _mosaic_wait_until "$timeout" \
    bash -c "[ \"\$(tmux -L $(_mosaic_socket) show-option -pqv -t '$pane' '@mosaic-_owner-generation' 2>/dev/null)\" = \"$expected\" ]"
}

_mosaic_wait_option_changed_from() {
  local opt="${1:?opt required}" old="${2:?old value required}" target="${3:-t:1}" timeout="${4:-3000}"
  _mosaic_wait_until "$timeout" \
    bash -c "v=\$(tmux -L $(_mosaic_socket) show-option -wqv -t '$target' '$opt' 2>/dev/null); [ -n \"\$v\" ] && [ \"\$v\" != \"$old\" ]"
}

_mosaic_fingerprint() {
  _mosaic_t show-option -wqv -t "${1:-t:1}" "@mosaic-_fingerprint" 2>/dev/null
}

_mosaic_wait_fingerprint_changed_from() {
  local old="${1-}" target="${2:-t:1}" timeout="${3:-3000}"
  _mosaic_wait_until "$timeout" \
    bash -c "v=\$(tmux -L $(_mosaic_socket) show-option -wqv -t '$target' '@mosaic-_fingerprint' 2>/dev/null); [ \"\$v\" != \"$old\" ]"
}

_mosaic_wait_pane_count() {
  local expected="${1:?expected required}" target="${2:-t:1}" timeout="${3:-3000}"
  _mosaic_wait_until "$timeout" \
    bash -c "[ \"\$(tmux -L $(_mosaic_socket) display-message -p -t '$target' '#{window_panes}' 2>/dev/null)\" = '$expected' ]"
}

_mosaic_wait_pane_count_gt() {
  local min="${1:?min required}" target="${2:-t:1}" timeout="${3:-3000}"
  _mosaic_wait_until "$timeout" \
    bash -c "[ \"\$(tmux -L $(_mosaic_socket) display-message -p -t '$target' '#{window_panes}' 2>/dev/null || echo 0)\" -gt $min ]"
}

_mosaic_wait_pane_present() {
  local pane="${1:?pane required}" target="${2:-t:1}" timeout="${3:-3000}"
  _mosaic_wait_until "$timeout" \
    bash -c "[ \"\$(tmux -L $(_mosaic_socket) list-panes -t '$target' -F '#{pane_id}' | grep -c '^$pane\$')\" = '1' ]"
}

_mosaic_wait_pane_dead() {
  local pane="${1:?pane required}" timeout="${2:-3000}"
  _mosaic_wait_until "$timeout" \
    bash -c "[ \"\$(tmux -L $(_mosaic_socket) display-message -p -t '$pane' '#{pane_dead}' 2>/dev/null)\" = '1' ]"
}

_mosaic_wait_pane_left_gt() {
  local idx="${1:?idx required}" min="${2:?min required}" target="${3:-t:1}" timeout="${4:-3000}"
  _mosaic_wait_until "$timeout" \
    bash -c "[ \"\$(tmux -L $(_mosaic_socket) list-panes -t '$target' -F '#{pane_index} #{pane_left}' | awk -v i=$idx '\$1 == i { print \$2 }')\" -gt \"$min\" ]"
}

_mosaic_wait_layout_outer() {
  local expected="${1:?[ or { required}" target="${2:-t:1}" timeout="${3:-3000}"
  _mosaic_wait_until "$timeout" \
    bash -c "[ \"\$(tmux -L $(_mosaic_socket) display-message -p -t '$target' '#{window_layout}' | cut -d, -f2- | awk 'match(\$0, /[\\[{]/) { print substr(\$0, RSTART, 1); exit }')\" = '$expected' ]"
}

_mosaic_wait_window_zoomed() {
  local expected="${1:?0 or 1 required}" target="${2:-t:1}" timeout="${3:-3000}"
  _mosaic_wait_until "$timeout" \
    bash -c "[ \"\$(tmux -L $(_mosaic_socket) display-message -p -t '$target' '#{window_zoomed_flag}' 2>/dev/null)\" = '$expected' ]"
}
