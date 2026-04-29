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

layout_new_pane_trace() {
  local layout="${1:?layout required}" target="${2:-t:1}" setup="${3:-}" trace_file
  trace_file=$(mktemp)
  REPO_ROOT="$REPO_ROOT" LAYOUT="$layout" TARGET="$target" SETUP="$setup" TRACE_FILE="$trace_file" bash -lc '
    set -euo pipefail
    source "$REPO_ROOT/scripts/helpers.sh"
    _mosaic_window_last_pane() { printf "%s\n" "%9"; }
    _mosaic_new_pane_split() { printf "split:%s\n" "$*" >>"$TRACE_FILE"; printf "%s\n" "%10"; }
    _mosaic_new_pane_append() { printf "append:%s\n" "$*" >>"$TRACE_FILE"; printf "%s\n" "%10"; }
    _mosaic_bubble_keep_focus() { printf "bubble:%s->%s\n" "$1" "$2" >>"$TRACE_FILE"; }
    source "$REPO_ROOT/scripts/layouts/$LAYOUT.sh"
    eval "$SETUP"
    _layout_new_pane "$TARGET" >/dev/null
    cat "$TRACE_FILE"
  '
  rm -f "$trace_file"
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

assert_master_stack_all_masters_trace() {
  local orientation="${1:?orientation required}" count="${2:?count required}" expected="${3:?expected trace required}" setup
  setup="_mosaic_window_pane_count() { printf '%s\\n' $count; }
_mosaic_effective_nmaster() { printf '%s\\n' $count; }
_layout_orientation_for() { printf '%s\\n' $orientation; }
_mosaic_window_pane_base() { printf '%s\\n' 1; }"

  run layout_new_pane_trace master-stack t:1 "$setup"
  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
}

assert_master_stack_first_stack_signature() {
  local orientation="${1:?orientation required}" expected="${2:?expected signature required}" setup
  setup="_mosaic_window_pane_count() { printf '%s\\n' 1; }
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

assert_default_tail_signature() {
  local layout="${1:?layout required}" count="${2:?count required}" expected="${3:?expected signature required}" setup
  setup="_mosaic_window_pane_count() { printf '%s\\n' $count; }
_mosaic_nmaster_for() { printf '%s\\n' 1; }"

  run layout_new_pane_signature "$layout" t:1 "$setup"
  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
}

assert_grid_signature() {
  local count="${1:?count required}" expected="${2:?expected signature required}" setup
  setup="_mosaic_window_pane_count() { printf '%s\\n' $count; }"

  run layout_new_pane_signature grid t:1 "$setup"
  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
}

assert_recursive_signature() {
  local layout="${1:?layout required}" count="${2:?count required}" expected="${3:?expected signature required}" setup
  setup="_mosaic_window_pane_count() { printf '%s\\n' $count; }"

  run layout_new_pane_signature "$layout" t:1 "$setup"
  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
}

assert_split_failure_falls_back() {
  local layout="${1:?layout required}" count="${2:?count required}" expected="${3:?expected signature required}" setup
  setup="_mosaic_window_pane_count() { printf '%s\\n' $count; }
_mosaic_new_pane_split() { return 1; }
_mosaic_new_pane_append() { printf '$expected\\n'; }"

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

@test "new-pane fast paths: grid 1 -> 2 keeps the default split on the tail" {
  assert_grid_signature 1 "split:%9"
}

@test "new-pane fast paths: grid 2 -> 3 keeps the default split on the tail" {
  assert_grid_signature 2 "split:%9"
}

@test "new-pane fast paths: grid 3 -> 4 targets the tail with a horizontal split" {
  assert_grid_signature 3 "split:%9 -h"
}

@test "new-pane fast paths: grid 4 -> 5 keeps the default split for an unavoidable global reshape" {
  assert_grid_signature 4 "split:%9"
}

@test "new-pane fast paths: grid 5 -> 6 targets the tail with a horizontal split" {
  assert_grid_signature 5 "split:%9 -h"
}

@test "new-pane fast paths: grid 6 -> 7 keeps the default split for an unavoidable global reshape" {
  assert_grid_signature 6 "split:%9"
}

@test "new-pane fast paths: grid 2 -> 3 keeps the new pane in the bottom tail before relayout" {
  local before old_tail pane
  _mosaic_use_layout grid
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  _mosaic_split t:1
  _mosaic_t select-pane -t t:1.1
  old_tail=$(_mosaic_pane_id_at t:1.2)
  before=$(_mosaic_pane_ids t:1)

  run layout_new_pane_direct grid t:1
  [ "$status" -eq 0 ]
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id t:1)" = "$pane" ]
  [ "$(_mosaic_pane_left "$pane")" = "$(_mosaic_pane_left "$old_tail")" ]
  [ "$(_mosaic_pane_top "$pane")" -gt "$(_mosaic_pane_top "$old_tail")" ]
}

@test "new-pane fast paths: grid 3 -> 4 splits the bottom tail to the right before relayout" {
  local before old_tail pane
  _mosaic_use_layout grid
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  _mosaic_split t:1
  _mosaic_split t:1
  _mosaic_t select-pane -t t:1.1
  old_tail=$(_mosaic_pane_id_at t:1.3)
  before=$(_mosaic_pane_ids t:1)

  run layout_new_pane_direct grid t:1
  [ "$status" -eq 0 ]
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id t:1)" = "$pane" ]
  [ "$(_mosaic_pane_left "$pane")" -gt "$(_mosaic_pane_left "$old_tail")" ]
  [ "$(_mosaic_pane_top "$pane")" = "$(_mosaic_pane_top "$old_tail")" ]
}

@test "new-pane fast paths: grid 4 -> 5 keeps the new pane in the tail pane's lower band before relayout" {
  local before old_tail pane
  _mosaic_use_layout grid
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  _mosaic_split t:1
  _mosaic_split t:1
  _mosaic_split t:1
  _mosaic_t select-pane -t t:1.1
  old_tail=$(_mosaic_pane_id_at t:1.4)
  before=$(_mosaic_pane_ids t:1)

  run layout_new_pane_direct grid t:1
  [ "$status" -eq 0 ]
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id t:1)" = "$pane" ]
  [ "$(_mosaic_pane_left "$pane")" = "$(_mosaic_pane_left "$old_tail")" ]
  [ "$(_mosaic_pane_top "$pane")" -gt "$(_mosaic_pane_top "$old_tail")" ]
}

@test "new-pane fast paths: master-stack existing left stack targets the tail directly" {
  assert_master_stack_signature left "split:%9"
}

@test "new-pane fast paths: master-stack first left stack pane uses a horizontal split" {
  assert_master_stack_first_stack_signature left "split:%9 -h"
}

@test "new-pane fast paths: master-stack first top stack pane keeps the default split" {
  assert_master_stack_first_stack_signature top "split:%9"
}

@test "new-pane fast paths: master-stack first right stack pane preserves append order with a horizontal split" {
  assert_master_stack_first_stack_signature right "split:%9 -h"
}

@test "new-pane fast paths: master-stack first bottom stack pane preserves append order with the default split" {
  assert_master_stack_first_stack_signature bottom "split:%9"
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

@test "new-pane fast paths: master-stack all-masters left transition splits the tail into the future stack branch" {
  assert_master_stack_all_masters_trace left 2 "split:%9 -h"
}

@test "new-pane fast paths: master-stack all-masters top transition splits the tail into the future stack branch" {
  assert_master_stack_all_masters_trace top 2 "split:%9"
}

@test "new-pane fast paths: master-stack all-masters right transition splits the first master and bubbles the new pane to the tail" {
  assert_master_stack_all_masters_trace right 2 $'split:t:1.1 -h -b\nbubble:1->3'
}

@test "new-pane fast paths: master-stack all-masters bottom transition splits the first master and bubbles the new pane to the tail" {
  assert_master_stack_all_masters_trace bottom 2 $'split:t:1.1 -b\nbubble:1->3'
}

@test "new-pane fast paths: master-stack mirrored all-masters transitions scale the bubble target with nmaster" {
  assert_master_stack_all_masters_trace right 3 $'split:t:1.1 -h -b\nbubble:1->4'
}

@test "new-pane fast paths: master-stack all-masters left transition starts the new pane on the right before relayout" {
  local before pane
  _mosaic_use_layout master-stack
  _mosaic_t set-option -wq -t t:1 "@mosaic-orientation" "left"
  _mosaic_t set-option -wq -t t:1 "@mosaic-nmaster" "2"
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  _mosaic_split t:1
  _mosaic_t select-pane -t t:1.1
  before=$(_mosaic_pane_ids t:1)

  run layout_new_pane_direct master-stack t:1
  [ "$status" -eq 0 ]
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id t:1)" = "$pane" ]
  [ "$(_mosaic_pane_left "$pane")" -gt 0 ]
}

@test "new-pane fast paths: master-stack left 1 -> 2 starts the new pane on the right before relayout" {
  local before pane
  _mosaic_use_layout master-stack
  _mosaic_t set-option -wq -t t:1 "@mosaic-orientation" "left"
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  before=$(_mosaic_pane_ids t:1)

  run layout_new_pane_direct master-stack t:1
  [ "$status" -eq 0 ]
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id t:1)" = "$pane" ]
  [ "$(_mosaic_pane_left "$pane")" -gt 0 ]
  [ "$(_mosaic_pane_top "$pane")" -eq 0 ]
}

@test "new-pane fast paths: master-stack top 1 -> 2 starts the new pane at the bottom before relayout" {
  local before pane
  _mosaic_use_layout master-stack
  _mosaic_t set-option -wq -t t:1 "@mosaic-orientation" "top"
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  before=$(_mosaic_pane_ids t:1)

  run layout_new_pane_direct master-stack t:1
  [ "$status" -eq 0 ]
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id t:1)" = "$pane" ]
  [ "$(_mosaic_pane_left "$pane")" -eq 0 ]
  [ "$(_mosaic_pane_top "$pane")" -gt 0 ]
}

@test "new-pane fast paths: master-stack right 1 -> 2 keeps the new pane at the tail and in a side split before relayout" {
  local before pane
  _mosaic_use_layout master-stack
  _mosaic_t set-option -wq -t t:1 "@mosaic-orientation" "right"
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  before=$(_mosaic_pane_ids t:1)

  run layout_new_pane_direct master-stack t:1
  [ "$status" -eq 0 ]
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id t:1)" = "$pane" ]
  [ "$(_mosaic_pane_left "$pane")" -gt 0 ]
  [ "$(_mosaic_pane_top "$pane")" -eq 0 ]
}

@test "new-pane fast paths: master-stack bottom 1 -> 2 keeps the new pane at the tail and in a bottom split before relayout" {
  local before pane
  _mosaic_use_layout master-stack
  _mosaic_t set-option -wq -t t:1 "@mosaic-orientation" "bottom"
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  before=$(_mosaic_pane_ids t:1)

  run layout_new_pane_direct master-stack t:1
  [ "$status" -eq 0 ]
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id t:1)" = "$pane" ]
  [ "$(_mosaic_pane_left "$pane")" -eq 0 ]
  [ "$(_mosaic_pane_top "$pane")" -gt 0 ]
}

@test "new-pane fast paths: master-stack all-masters right transition keeps the new pane on the left and at the tail before relayout" {
  local before pane
  _mosaic_use_layout master-stack
  _mosaic_t set-option -wq -t t:1 "@mosaic-orientation" "right"
  _mosaic_t set-option -wq -t t:1 "@mosaic-nmaster" "2"
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  _mosaic_split t:1
  _mosaic_t select-pane -t t:1.2
  before=$(_mosaic_pane_ids t:1)

  run layout_new_pane_direct master-stack t:1
  [ "$status" -eq 0 ]
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id t:1)" = "$pane" ]
  [ "$(_mosaic_pane_left "$pane")" -eq 0 ]
}

@test "new-pane fast paths: master-stack all-masters bottom transition keeps the new pane on the top and at the tail before relayout" {
  local before pane
  _mosaic_use_layout master-stack
  _mosaic_t set-option -wq -t t:1 "@mosaic-orientation" "bottom"
  _mosaic_t set-option -wq -t t:1 "@mosaic-nmaster" "2"
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  _mosaic_split t:1
  _mosaic_t select-pane -t t:1.2
  before=$(_mosaic_pane_ids t:1)

  run layout_new_pane_direct master-stack t:1
  [ "$status" -eq 0 ]
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id t:1)" = "$pane" ]
  [ "$(_mosaic_pane_top "$pane")" -eq 0 ]
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

@test "new-pane fast paths: centered-master first left-stack transition targets the tail directly" {
  assert_default_tail_signature centered-master 2 "split:%9"
}

@test "new-pane fast paths: centered-master later parity transitions still target the right tail directly" {
  assert_default_tail_signature centered-master 4 "split:%9"
}

@test "new-pane fast paths: three-column first middle-column transition targets the tail directly" {
  assert_default_tail_signature three-column 2 "split:%9"
}

@test "new-pane fast paths: three-column later parity transitions still target the right tail directly" {
  assert_default_tail_signature three-column 3 "split:%9"
}

@test "new-pane fast paths: dwindle targets the recursive tail with the master split first" {
  assert_recursive_signature dwindle 1 "split:%9 -h"
}

@test "new-pane fast paths: dwindle alternates to a vertical tail split on the third pane" {
  assert_recursive_signature dwindle 2 "split:%9"
}

@test "new-pane fast paths: dwindle alternates back to a horizontal tail split on the fourth pane" {
  assert_recursive_signature dwindle 3 "split:%9 -h"
}

@test "new-pane fast paths: dwindle falls back to append when the recursive tail split fails" {
  assert_split_failure_falls_back dwindle 3 "append:t:1"
}

@test "new-pane fast paths: dwindle 1 -> 2 starts with the new pane on the right before relayout" {
  local before pane
  _mosaic_use_layout dwindle
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  before=$(_mosaic_pane_ids t:1)

  run layout_new_pane_direct dwindle t:1
  [ "$status" -eq 0 ]
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id t:1)" = "$pane" ]
  [ "$(_mosaic_pane_left "$pane")" -gt 0 ]
  [ "$(_mosaic_pane_top "$pane")" -eq 0 ]
}

@test "new-pane fast paths: spiral targets the first leaf-node birth with the master split" {
  assert_recursive_signature spiral 1 "split:%9 -h"
}

@test "new-pane fast paths: spiral targets the second leaf-node birth with a vertical tail split" {
  assert_recursive_signature spiral 2 "split:%9"
}

@test "new-pane fast paths: spiral targets the first node-leaf phase with a horizontal tail split" {
  assert_recursive_signature spiral 3 "split:%9 -h"
}

@test "new-pane fast paths: spiral falls back to append when the recursive tail split fails" {
  assert_split_failure_falls_back spiral 3 "append:t:1"
}

@test "new-pane fast paths: spiral later node-leaf phases keep targeting the outer tail with a horizontal split" {
  assert_recursive_signature spiral 6 "split:%9 -h"
}

@test "new-pane fast paths: spiral 1 -> 2 starts with the new pane on the right before relayout" {
  local before pane
  _mosaic_use_layout spiral
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  before=$(_mosaic_pane_ids t:1)

  run layout_new_pane_direct spiral t:1
  [ "$status" -eq 0 ]
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id t:1)" = "$pane" ]
  [ "$(_mosaic_pane_left "$pane")" -gt 0 ]
  [ "$(_mosaic_pane_top "$pane")" -eq 0 ]
}

@test "new-pane fast paths: spiral 2 -> 3 places the new pane below the tail before relayout" {
  local before pane old_tail
  _mosaic_use_layout spiral
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  _mosaic_split t:1
  old_tail=$(_mosaic_pane_id_at t:1.2)
  before=$(_mosaic_pane_ids t:1)

  run layout_new_pane_direct spiral t:1
  [ "$status" -eq 0 ]
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id t:1)" = "$pane" ]
  [ "$(_mosaic_pane_left "$pane")" = "$(_mosaic_pane_left "$old_tail")" ]
  [ "$(_mosaic_pane_top "$pane")" -gt "$(_mosaic_pane_top "$old_tail")" ]
}

@test "new-pane fast paths: spiral 3 -> 4 keeps the new pane in the outer right branch before relayout" {
  local before old_tail pane
  _mosaic_use_layout spiral
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  _mosaic_split t:1
  _mosaic_split t:1
  old_tail=$(_mosaic_pane_id_at t:1.3)
  before=$(_mosaic_pane_ids t:1)

  run layout_new_pane_direct spiral t:1
  [ "$status" -eq 0 ]
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id t:1)" = "$pane" ]
  [ "$(_mosaic_pane_left "$pane")" -gt "$(_mosaic_pane_left "$old_tail")" ]
  [ "$(_mosaic_pane_top "$pane")" = "$(_mosaic_pane_top "$old_tail")" ]
}

@test "new-pane fast paths: spiral 4 -> 5 keeps the new pane in the outer right branch before relayout" {
  local before old_tail pane
  _mosaic_use_layout spiral
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  _mosaic_split t:1
  _mosaic_split t:1
  _mosaic_split t:1
  old_tail=$(_mosaic_pane_id_at t:1.4)
  before=$(_mosaic_pane_ids t:1)

  run layout_new_pane_direct spiral t:1
  [ "$status" -eq 0 ]
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id t:1)" = "$pane" ]
  [ "$(_mosaic_pane_left "$pane")" -gt "$(_mosaic_pane_left "$old_tail")" ]
  [ "$(_mosaic_pane_top "$pane")" = "$(_mosaic_pane_top "$old_tail")" ]
}
