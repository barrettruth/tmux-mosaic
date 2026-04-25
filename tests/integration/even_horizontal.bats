#!/usr/bin/env bats

load '../helpers.bash'

setup() {
  mosaic_setup_server
  mosaic_t set-option -wq -t t:1 "@mosaic-algorithm" "even-horizontal"
}

teardown() {
  mosaic_teardown_server
}

@test "even-horizontal: 4 panes are arranged in an equal-width row" {
  for _ in 1 2 3; do mosaic_split; done
  [ "$(mosaic_pane_count)" = "4" ]

  layout=$(mosaic_layout)
  [[ "$layout" == *"{"* ]]
  [[ "$layout" != *"["* ]]

  widths=$(mosaic_t list-panes -t t:1 -F '#{pane_width}' | sort -n)
  min=$(printf '%s\n' "$widths" | head -n1)
  max=$(printf '%s\n' "$widths" | tail -n1)

  [ $((max - min)) -le 1 ]
}
