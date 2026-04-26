#!/usr/bin/env bash

_mosaic_set_defaults() {
  tmux set-option -gwq "@mosaic-orientation" "left"
  tmux set-option -gwq "@mosaic-nmaster" "1"
  tmux set-option -gq "@mosaic-mfact" "50"
  tmux set-option -gq "@mosaic-step" "5"
  tmux set-option -gq "@mosaic-debug" "0"
}

_mosaic_register_hooks() {
  local exec hook _layout_option_filter
  exec=$(tmux show-option -gqv "@mosaic-exec")
  [[ -z "$exec" ]] && return 0

  for hook in after-split-window after-kill-pane pane-exited pane-died after-select-pane; do
    tmux set-hook -ga "$hook" "run-shell -b '$exec relayout #{window_id}'"
  done
  tmux set-hook -ga after-resize-pane \
    "run-shell -b '$exec _sync-state #{window_id}'"

  _layout_option_filter='#{||:#{||:#{m:@mosaic-layout,#{hook_argument_0}},#{m:@mosaic-orientation,#{hook_argument_0}}},#{||:#{m:@mosaic-nmaster,#{hook_argument_0}},#{m:@mosaic-mfact,#{hook_argument_0}}}}'
  tmux set-hook -ga after-set-option \
    "if-shell -bF '$_layout_option_filter' \"run-shell -b '$exec _on-set-option #{hook_argument_0} #{window_id}'\""
}
