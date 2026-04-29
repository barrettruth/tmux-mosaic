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
  printf '%s\n' "${MOSAIC_TEST_SOCKET:-mosaic-test}-$(_mosaic_test_instance_id)"
}

_mosaic_t() { tmux -L "$(_mosaic_socket)" "$@"; }

_mosaic_test_tmpdir() {
  if [[ -n "${BATS_TEST_TMPDIR:-}" ]]; then
    printf '%s\n' "$BATS_TEST_TMPDIR"
  else
    printf '%s\n' "${TMPDIR:-/tmp}/tmux-mosaic-tests/$(_mosaic_test_id)"
  fi
}

_mosaic_log_file() {
  printf '%s\n' "$(_mosaic_test_tmpdir)/tmux-mosaic-test.log"
}

_mosaic_bash_exec() {
  printf 'bash %q' "${1:?path required}"
}

_mosaic_shell_command() {
  local cmd="${1:?command required}" arg
  shift
  printf '%s' "$cmd"
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
}

_mosaic_source_plugin() {
  local root="${1:-$REPO_ROOT}"
  _mosaic_t run-shell "$(_mosaic_bash_exec "$root/mosaic.tmux")"
}

_mosaic_setup_server() {
  local x="${1:-200}" y="${2:-50}"
  _mosaic_t kill-server 2>/dev/null || true
  mkdir -p "$(_mosaic_test_tmpdir)"
  rm -f "$(_mosaic_log_file)"
  local conf
  conf="$(_mosaic_test_tmpdir)/$(_mosaic_socket).conf"
  cat >"$conf" <<EOF
set -g base-index 1
set -g pane-base-index 1
set -g default-terminal "screen-256color"
run-shell "$(_mosaic_bash_exec "$REPO_ROOT/mosaic.tmux")"
set-option -gq @mosaic-debug 1
set-option -gq @mosaic-log-file "$(_mosaic_log_file)"
EOF
  _mosaic_t -f "$conf" new-session -d -s t -x "$x" -y "$y" "sleep 3600"
  if ! _mosaic_wait_until 3000 _mosaic_global_option_set_p "@mosaic-exec"; then
    _mosaic_source_plugin
  fi
  if ! _mosaic_wait_until 3000 _mosaic_global_option_set_p "@mosaic-exec"; then
    {
      printf 'mosaic setup failed\n'
      printf 'conf=%s\n' "$conf"
      cat "$conf"
      printf 'default-shell=%s\n' "$(_mosaic_t show-option -gqv default-shell 2>/dev/null || true)"
      printf 'default-command=%s\n' "$(_mosaic_t show-option -gqv default-command 2>/dev/null || true)"
      printf '@mosaic-exec=%s\n' "$(_mosaic_t show-option -gqv @mosaic-exec 2>/dev/null || true)"
      printf 'socket=%s\n' "$(_mosaic_t display-message -p '#{socket_path}' 2>/dev/null || true)"
      printf 'pane_current_path=%s\n' "$(_mosaic_t display-message -p -t t:1 '#{pane_current_path}' 2>/dev/null || true)"
      _mosaic_t show-environment -g 2>/dev/null | grep -E '^(HOME|PATH|PWD|SHELL|TMUX_TMPDIR|XDG_RUNTIME_DIR)=' || true
      ls -l "$REPO_ROOT/mosaic.tmux" "$REPO_ROOT/scripts/helpers.sh" "$REPO_ROOT/scripts/defaults.sh" 2>&1 || true
      _mosaic_t show-messages -JT 2>/dev/null || true
    } >&2
    return 1
  fi
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

_mosaic_effective_layout() {
  local target="${1:-t:1}" val
  val=$(_mosaic_t show-option -wqv -t "$target" "@mosaic-layout" 2>/dev/null)
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

  val=$(_mosaic_t show-option -gwqv "@mosaic-layout" 2>/dev/null)
  case "$val" in
  '' | off) printf '\n' ;;
  *) printf '%s\n' "$val" ;;
  esac
}

_mosaic_effective_window_option() {
  local target="${1:-t:1}" opt="${2:?opt required}" default="${3-}" val
  val=$(_mosaic_t show-option -wqvA -t "$target" "$opt" 2>/dev/null)
  printf '%s\n' "${val:-$default}"
}

_mosaic_expected_fingerprint() {
  local target="${1:-t:1}" layout n mfact nmaster orientation window_w window_h zoomed
  layout=$(_mosaic_effective_layout "$target")
  n=$(_mosaic_t display-message -p -t "$target" '#{window_panes}' 2>/dev/null || printf '0\n')
  mfact=$(_mosaic_effective_window_option "$target" "@mosaic-mfact" "50")
  nmaster=$(_mosaic_effective_window_option "$target" "@mosaic-nmaster" "1")
  orientation=$(_mosaic_effective_window_option "$target" "@mosaic-orientation" "left")
  window_w=$(_mosaic_t display-message -p -t "$target" '#{window_width}' 2>/dev/null)
  window_h=$(_mosaic_t display-message -p -t "$target" '#{window_height}' 2>/dev/null)
  zoomed=$(_mosaic_t display-message -p -t "$target" '#{window_zoomed_flag}' 2>/dev/null)
  printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
    "$layout" "$n" "$mfact" "$nmaster" "$orientation" "$window_w" "$window_h" "$zoomed"
}

_mosaic_fingerprint_current_p() {
  local target="${1:-t:1}" actual expected pending
  actual=$(_mosaic_fingerprint "$target")
  expected=$(_mosaic_expected_fingerprint "$target")
  pending=$(_mosaic_window_option_value "$target" "@mosaic-_pending-fingerprint")
  [[ -n "$actual" && -z "$pending" && "$actual" = "$expected" ]]
}

_mosaic_wait_fingerprint_current() {
  local target="${1:-t:1}" timeout="${2:-3000}" layout
  layout=$(_mosaic_effective_layout "$target")
  [[ -n "$layout" ]] || return 0
  _mosaic_wait_until "$timeout" _mosaic_fingerprint_current_p "$target"
}

_mosaic_split() {
  local target="${1:-t:1}" before fp layout
  _mosaic_quiesce
  _mosaic_wait_fingerprint_current "$target"
  before=$(_mosaic_t display-message -p -t "$target" '#{window_panes}' 2>/dev/null || echo 0)
  fp=$(_mosaic_fingerprint "$target")
  layout=$(_mosaic_effective_layout "$target")
  _mosaic_t split-window -t "$target" "sleep 3600"
  _mosaic_wait_pane_count_gt "$before" "$target"
  if [[ -n "$layout" && "$layout" != "off" ]]; then
    if [[ -n "$fp" ]]; then
      _mosaic_wait_fingerprint_changed_from "$fp" "$target"
    else
      _mosaic_wait_option_set "@mosaic-_fingerprint" "$target"
    fi
    _mosaic_wait_fingerprint_current "$target"
  fi
  _mosaic_quiesce
}

_mosaic_raw_split() {
  _mosaic_t split-window -P -F '#{pane_id}' "$@" "sleep 3600"
}

_mosaic_new_pane() {
  local target="${1:-t:1}" before before_count fp layout pane
  _mosaic_quiesce
  _mosaic_wait_fingerprint_current "$target"
  before=$(_mosaic_pane_ids "$target")
  before_count=$(_mosaic_pane_count "$target")
  fp=$(_mosaic_fingerprint "$target")
  layout=$(_mosaic_effective_layout "$target")
  _mosaic_exec_direct new-pane >/dev/null
  _mosaic_wait_pane_count_gt "$before_count" "$target"
  if [[ -n "$layout" && "$layout" != "off" ]]; then
    if [[ -n "$fp" ]]; then
      _mosaic_wait_fingerprint_changed_from "$fp" "$target"
    else
      _mosaic_wait_option_set "@mosaic-_fingerprint" "$target"
    fi
    _mosaic_wait_fingerprint_current "$target"
  fi
  pane=$(_mosaic_new_pane_id_from "$before" "$target") || return 1
  _mosaic_wait_pane_present "$pane" "$target"
  _mosaic_quiesce
  printf '%s\n' "$pane"
}

_mosaic_socket_path() {
  printf '%s\n' "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$(_mosaic_socket)"
}

_mosaic_exec_direct() {
  local exec sock cmd
  exec=$(_mosaic_t show-option -gqv "@mosaic-exec")
  sock=$(_mosaic_socket_path)
  cmd=$(_mosaic_shell_command "$exec" "$@")
  TMUX="$sock,$$,0" bash -c "$cmd"
}

_mosaic_pane_id_at() {
  _mosaic_t display-message -p -t "${1:?index required}" '#{pane_id}'
}

_mosaic_pane_current_path() {
  _mosaic_t display-message -p -t "${1:?target required}" '#{pane_current_path}'
}

_mosaic_pane_field() {
  local target="${1:?target required}" field="${2:?field required}"
  _mosaic_t display-message -p -t "$target" "#{$field}"
}

_mosaic_pane_left() {
  _mosaic_pane_field "${1:?target required}" pane_left
}

_mosaic_pane_top() {
  _mosaic_pane_field "${1:?target required}" pane_top
}

_mosaic_pane_width() {
  _mosaic_pane_field "${1:?target required}" pane_width
}

_mosaic_pane_height() {
  _mosaic_pane_field "${1:?target required}" pane_height
}

_mosaic_pane_rect() {
  _mosaic_t display-message -p -t "${1:?target required}" '#{pane_left} #{pane_top} #{pane_width} #{pane_height}'
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
  _mosaic_t run-shell "$(_mosaic_shell_command "$exec" "$@")"
}

_mosaic_panes_summary() {
  _mosaic_t list-panes -t "${1:-t:1}" -F '#{pane_index}:#{pane_id}' | paste -sd' '
}

_mosaic_pane_ids() {
  _mosaic_t list-panes -t "${1:-t:1}" -F '#{pane_id}'
}

_mosaic_last_pane_id() {
  _mosaic_t list-panes -t "${1:-t:1}" -F '#{pane_id}' | tail -n1
}

_mosaic_new_pane_id_from() {
  local before="${1-}" target="${2:-t:1}" pane
  while IFS= read -r pane; do
    [[ -n "$pane" ]] || continue
    if ! grep -Fxq "$pane" <<<"$before"; then
      printf '%s\n' "$pane"
      return 0
    fi
  done < <(_mosaic_pane_ids "$target")
  return 1
}

_mosaic_rect_contains() {
  local outer_left="${1:?outer left required}" outer_top="${2:?outer top required}" outer_width="${3:?outer width required}" outer_height="${4:?outer height required}"
  local inner_left="${5:?inner left required}" inner_top="${6:?inner top required}" inner_width="${7:?inner width required}" inner_height="${8:?inner height required}"
  local outer_right inner_right outer_bottom inner_bottom
  outer_right=$((outer_left + outer_width - 1))
  inner_right=$((inner_left + inner_width - 1))
  outer_bottom=$((outer_top + outer_height - 1))
  inner_bottom=$((inner_top + inner_height - 1))
  [[ "$inner_left" -ge "$outer_left" &&
    "$inner_top" -ge "$outer_top" &&
    "$inner_right" -le "$outer_right" &&
    "$inner_bottom" -le "$outer_bottom" ]]
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

_mosaic_global_option_value() {
  _mosaic_t show-option -gqv "${1:?opt required}" 2>/dev/null
}

_mosaic_global_option_set_p() {
  [[ -n "$(_mosaic_global_option_value "${1:?opt required}")" ]]
}

_mosaic_window_option_value() {
  local target="${1:-t:1}" opt="${2:?opt required}"
  _mosaic_t show-option -wqv -t "$target" "$opt" 2>/dev/null
}

_mosaic_window_option_is_p() {
  local target="${1:-t:1}" opt="${2:?opt required}" expected="${3-}"
  [[ "$(_mosaic_window_option_value "$target" "$opt")" = "$expected" ]]
}

_mosaic_window_option_set_p() {
  local target="${1:-t:1}" opt="${2:?opt required}"
  [[ -n "$(_mosaic_window_option_value "$target" "$opt")" ]]
}

_mosaic_window_option_empty_p() {
  local target="${1:-t:1}" opt="${2:?opt required}"
  [[ -z "$(_mosaic_window_option_value "$target" "$opt")" ]]
}

_mosaic_window_option_changed_from_p() {
  local target="${1:-t:1}" opt="${2:?opt required}" old="${3-}" v
  v=$(_mosaic_window_option_value "$target" "$opt")
  [[ -n "$v" && "$v" != "$old" ]]
}

_mosaic_pane_option_value() {
  local pane="${1:?pane required}" opt="${2:?opt required}"
  _mosaic_t show-option -pqv -t "$pane" "$opt" 2>/dev/null
}

_mosaic_pane_option_is_p() {
  local pane="${1:?pane required}" opt="${2:?opt required}" expected="${3-}"
  [[ "$(_mosaic_pane_option_value "$pane" "$opt")" = "$expected" ]]
}

_mosaic_relayout_count_ge_p() {
  local expected="${1:?expected count required}"
  [[ "$(_mosaic_log_relayout_count)" -ge "$expected" ]]
}

_mosaic_window_pane_count_value() {
  _mosaic_t display-message -p -t "${1:-t:1}" '#{window_panes}' 2>/dev/null || printf '0\n'
}

_mosaic_window_pane_count_is_p() {
  local target="${1:-t:1}" expected="${2:?expected required}"
  [[ "$(_mosaic_window_pane_count_value "$target")" = "$expected" ]]
}

_mosaic_window_pane_count_gt_p() {
  local target="${1:-t:1}" min="${2:?min required}"
  [[ "$(_mosaic_window_pane_count_value "$target")" -gt "$min" ]]
}

_mosaic_window_has_pane_p() {
  local target="${1:-t:1}" pane="${2:?pane required}"
  _mosaic_t list-panes -t "$target" -F '#{pane_id}' | grep -Fxq "$pane"
}

_mosaic_pane_dead_is_p() {
  local pane="${1:?pane required}" expected="${2:?0 or 1 required}"
  [[ "$(_mosaic_t display-message -p -t "$pane" '#{pane_dead}' 2>/dev/null)" = "$expected" ]]
}

_mosaic_pane_left_gt_p() {
  local idx="${1:?idx required}" min="${2:?min required}" target="${3:-t:1}" left
  left=$(_mosaic_t list-panes -t "$target" -F '#{pane_index} #{pane_left}' | awk -v i="$idx" '$1 == i { print $2 }')
  [[ -n "$left" && "$left" -gt "$min" ]]
}

_mosaic_layout_outer_is_p() {
  local target="${1:-t:1}" expected="${2:?[ or { required}"
  [[ "$(_mosaic_layout_outer "$target")" = "$expected" ]]
}

_mosaic_window_zoomed_is_p() {
  local target="${1:-t:1}" expected="${2:?0 or 1 required}"
  [[ "$(_mosaic_t display-message -p -t "$target" '#{window_zoomed_flag}' 2>/dev/null)" = "$expected" ]]
}

_mosaic_reset_log() {
  _mosaic_quiesce
  : >"$(_mosaic_log_file)"
}

_mosaic_wait_relayout_count_ge() {
  local expected="${1:?expected count required}" timeout="${2:-3000}"
  _mosaic_wait_until "$timeout" _mosaic_relayout_count_ge_p "$expected"
}

_mosaic_wait_log_match() {
  local pattern="${1:?pattern required}" timeout="${2:-3000}"
  _mosaic_wait_until "$timeout" grep -q "$pattern" "$(_mosaic_log_file)"
}

_mosaic_wait_option() {
  local opt="${1:?opt required}" expected="${2-}" target="${3:-t:1}" timeout="${4:-3000}"
  _mosaic_wait_until "$timeout" _mosaic_window_option_is_p "$target" "$opt" "$expected"
}

_mosaic_wait_option_empty() {
  _mosaic_wait_option "${1:?opt required}" "" "${2:-t:1}" "${3:-3000}"
}

_mosaic_wait_option_set() {
  local opt="${1:?opt required}" target="${2:-t:1}" timeout="${3:-3000}"
  _mosaic_wait_until "$timeout" _mosaic_window_option_set_p "$target" "$opt"
}

_mosaic_wait_window_generation_set() {
  local target="${1:-t:1}" timeout="${2:-3000}"
  _mosaic_wait_until "$timeout" _mosaic_window_option_set_p "$target" "@mosaic-_generation"
}

_mosaic_wait_window_generation_empty() {
  local target="${1:-t:1}" timeout="${2:-3000}"
  _mosaic_wait_until "$timeout" _mosaic_window_option_empty_p "$target" "@mosaic-_generation"
}

_mosaic_wait_window_state() {
  local expected="${1-}" target="${2:-t:1}" timeout="${3:-3000}"
  _mosaic_wait_until "$timeout" _mosaic_window_option_is_p "$target" "@mosaic-_state" "$expected"
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
  _mosaic_wait_until "$timeout" _mosaic_pane_option_is_p "$pane" "@mosaic-_owner-generation" "$expected"
}

_mosaic_wait_option_changed_from() {
  local opt="${1:?opt required}" old="${2:?old value required}" target="${3:-t:1}" timeout="${4:-3000}"
  _mosaic_wait_until "$timeout" _mosaic_window_option_changed_from_p "$target" "$opt" "$old"
}

_mosaic_fingerprint() {
  _mosaic_t show-option -wqv -t "${1:-t:1}" "@mosaic-_fingerprint" 2>/dev/null
}

_mosaic_wait_fingerprint_changed_from() {
  local old="${1-}" target="${2:-t:1}" timeout="${3:-3000}"
  _mosaic_wait_until "$timeout" _mosaic_window_option_changed_from_p "$target" "@mosaic-_fingerprint" "$old"
}

_mosaic_wait_pane_count() {
  local expected="${1:?expected required}" target="${2:-t:1}" timeout="${3:-3000}"
  _mosaic_wait_until "$timeout" _mosaic_window_pane_count_is_p "$target" "$expected"
}

_mosaic_wait_pane_count_gt() {
  local min="${1:?min required}" target="${2:-t:1}" timeout="${3:-3000}"
  _mosaic_wait_until "$timeout" _mosaic_window_pane_count_gt_p "$target" "$min"
}

_mosaic_wait_pane_present() {
  local pane="${1:?pane required}" target="${2:-t:1}" timeout="${3:-3000}"
  _mosaic_wait_until "$timeout" _mosaic_window_has_pane_p "$target" "$pane"
}

_mosaic_wait_pane_dead() {
  local pane="${1:?pane required}" timeout="${2:-3000}"
  _mosaic_wait_until "$timeout" _mosaic_pane_dead_is_p "$pane" 1
}

_mosaic_wait_pane_left_gt() {
  local idx="${1:?idx required}" min="${2:?min required}" target="${3:-t:1}" timeout="${4:-3000}"
  _mosaic_wait_until "$timeout" _mosaic_pane_left_gt_p "$idx" "$min" "$target"
}

_mosaic_wait_layout_outer() {
  local expected="${1:?[ or { required}" target="${2:-t:1}" timeout="${3:-3000}"
  _mosaic_wait_until "$timeout" _mosaic_layout_outer_is_p "$target" "$expected"
}

_mosaic_wait_window_zoomed() {
  local expected="${1:?0 or 1 required}" target="${2:-t:1}" timeout="${3:-3000}"
  _mosaic_wait_until "$timeout" _mosaic_window_zoomed_is_p "$target" "$expected"
}
