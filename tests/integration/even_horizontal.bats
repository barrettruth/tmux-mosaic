#!/usr/bin/env bats

load '../helpers.bash'

setup() {
  _mosaic_setup_server
  _mosaic_t set-option -wq -t t:1 "@mosaic-layout" "even-horizontal"
}

teardown() {
  _mosaic_teardown_server
}

@test "even-horizontal: 4 panes are arranged in an equal-width row" {
  for _ in 1 2 3; do _mosaic_split; done
  [ "$(_mosaic_pane_count)" = "4" ]

  layout=$(_mosaic_layout)
  [[ "$layout" == *"{"* ]]
  [[ "$layout" != *"["* ]]

  widths=$(_mosaic_t list-panes -t t:1 -F '#{pane_width}' | sort -n)
  min=$(printf '%s\n' "$widths" | head -n1)
  max=$(printf '%s\n' "$widths" | tail -n1)

  [ $((max - min)) -le 1 ]
}

@test "even-horizontal: promote surfaces the missing operation message in direct cli use" {
  run _mosaic_exec_direct promote
  [ "$status" -eq 0 ]
  [[ "$output" == *"mosaic: even-horizontal does not implement promote"* ]]
}

@test "even-horizontal: resize-master surfaces the missing operation message in direct cli use" {
  run _mosaic_exec_direct resize-master +5
  [ "$status" -eq 0 ]
  [[ "$output" == *"mosaic: even-horizontal does not implement resize-master"* ]]
}
