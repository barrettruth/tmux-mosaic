#!/usr/bin/env bats

load '../helpers.bash'

setup() {
  _mosaic_setup_server
}

teardown() {
  _mosaic_teardown_server
}

layout_new_pane_direct() {
  local layout="${1:?layout required}" target="${2:-t:1}" sock
  sock=$(_mosaic_socket_path)
  TMUX="$sock,$$,0" bash -lc "source '$REPO_ROOT/scripts/helpers.sh'; source '$REPO_ROOT/scripts/layouts/$layout.sh'; _layout_new_pane '$target'"
}

layout_new_pane_signature() {
  local layout="${1:?layout required}" target="${2:-t:1}" setup="${3:-}"
  REPO_ROOT="$REPO_ROOT" LAYOUT="$layout" TARGET="$target" SETUP="$setup" bash -lc '
    set -euo pipefail
    source "$REPO_ROOT/scripts/helpers.sh"
    _mosaic_window_last_pane() { printf "%s\n" "%9"; }
    _mosaic_new_pane_split() { printf "split:%s\n" "$*"; }
    _mosaic_new_pane_append() { printf "append:%s\n" "$*"; }
    source "$REPO_ROOT/scripts/layouts/$LAYOUT.sh"
    eval "$SETUP"
    _layout_new_pane "$TARGET"
  '
}

assert_master_stack_signature() {
  local orientation="${1:?orientation required}" expected="${2:?expected signature required}" setup
  setup="_mosaic_window_pane_count() { printf '%s\\n' 3; }
_mosaic_effective_nmaster() { printf '%s\\n' 1; }
_layout_orientation_for() { printf '%s\\n' $orientation; }"

  run layout_new_pane_signature master-stack t:1 "$setup"
  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
}

assert_single_side_signature() {
  local layout="${1:?layout required}" expected="${2:?expected signature required}" setup
  setup="_mosaic_window_pane_count() { printf '%s\\n' 1; }
_mosaic_nmaster_for() { printf '%s\\n' 1; }"

  run layout_new_pane_signature "$layout" t:1 "$setup"
  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
}

last_pane_id() {
  _mosaic_t list-panes -t "${1:-t:1}" -F '#{pane_id}' | tail -n1
}

distinct_pane_tops() {
  _mosaic_t list-panes -t "${1:-t:1}" -F '#{pane_top}' | sort -u | paste -sd' ' -
}

distinct_pane_lefts() {
  _mosaic_t list-panes -t "${1:-t:1}" -F '#{pane_left}' | sort -u | paste -sd' ' -
}

@test "new-pane fast paths: even-horizontal targets the tail with a horizontal split" {
  run layout_new_pane_signature even-horizontal t:1
  [ "$status" -eq 0 ]
  [ "$output" = "split:%9 -h" ]
}

@test "new-pane fast paths: even-horizontal 1 -> 2 starts as a row before relayout" {
  local before pane
  _mosaic_use_layout even-horizontal
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  before=$(_mosaic_pane_ids t:1)

  run layout_new_pane_direct even-horizontal t:1
  [ "$status" -eq 0 ]
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id t:1)" = "$pane" ]
  [ "$(distinct_pane_tops t:1)" = "0" ]
}

@test "new-pane fast paths: even-horizontal appending from the first pane stays in a row before relayout" {
  local before pane
  _mosaic_use_layout even-horizontal
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  _mosaic_split t:1
  _mosaic_split t:1
  _mosaic_t select-pane -t t:1.1
  before=$(_mosaic_pane_ids t:1)

  run layout_new_pane_direct even-horizontal t:1
  [ "$status" -eq 0 ]
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id t:1)" = "$pane" ]
  [ "$(distinct_pane_tops t:1)" = "0" ]
}

@test "new-pane fast paths: even-vertical targets the tail without a horizontal split" {
  run layout_new_pane_signature even-vertical t:1
  [ "$status" -eq 0 ]
  [ "$output" = "split:%9" ]
}

@test "new-pane fast paths: even-vertical 1 -> 2 starts as a column before relayout" {
  local before pane
  _mosaic_use_layout even-vertical
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  before=$(_mosaic_pane_ids t:1)

  run layout_new_pane_direct even-vertical t:1
  [ "$status" -eq 0 ]
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id t:1)" = "$pane" ]
  [ "$(distinct_pane_lefts t:1)" = "0" ]
}

@test "new-pane fast paths: even-vertical appending from the first pane stays in a column before relayout" {
  local before pane
  _mosaic_use_layout even-vertical
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  _mosaic_split t:1
  _mosaic_split t:1
  _mosaic_t select-pane -t t:1.1
  before=$(_mosaic_pane_ids t:1)

  run layout_new_pane_direct even-vertical t:1
  [ "$status" -eq 0 ]
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id t:1)" = "$pane" ]
  [ "$(distinct_pane_lefts t:1)" = "0" ]
}

@test "new-pane fast paths: master-stack existing left stack targets the tail directly" {
  assert_master_stack_signature left "split:%9"
}

@test "new-pane fast paths: master-stack existing right stack targets the tail directly" {
  assert_master_stack_signature right "split:%9"
}

@test "new-pane fast paths: master-stack existing top stack targets the tail directly" {
  assert_master_stack_signature top "split:%9 -h"
}

@test "new-pane fast paths: master-stack existing bottom stack targets the tail directly" {
  assert_master_stack_signature bottom "split:%9 -h"
}

@test "new-pane fast paths: centered-master targets the first side birth with a horizontal split" {
  assert_single_side_signature centered-master "split:%9 -h"
}

@test "new-pane fast paths: centered-master first side-stack pane starts on the right before relayout" {
  local before pane
  _mosaic_use_layout centered-master
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  before=$(_mosaic_pane_ids t:1)

  run layout_new_pane_direct centered-master t:1
  [ "$status" -eq 0 ]
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id t:1)" = "$pane" ]
  [ "$(_mosaic_pane_left "$pane")" -gt 0 ]
  [ "$(_mosaic_pane_top "$pane")" -eq 0 ]
}

@test "new-pane fast paths: three-column targets the first side birth with a horizontal split" {
  assert_single_side_signature three-column "split:%9 -h"
}

@test "new-pane fast paths: three-column first side-column pane starts on the right before relayout" {
  local before pane
  _mosaic_use_layout three-column
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  before=$(_mosaic_pane_ids t:1)

  run layout_new_pane_direct three-column t:1
  [ "$status" -eq 0 ]
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id t:1)" = "$pane" ]
  [ "$(_mosaic_pane_left "$pane")" -gt 0 ]
  [ "$(_mosaic_pane_top "$pane")" -eq 0 ]
}
