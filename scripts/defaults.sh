#!/usr/bin/env bash

mosaic_set_defaults() {
  tmux set-option -gwq "@mosaic-orientation" "left"
  tmux set-option -gq "@mosaic-mfact" "50"
  tmux set-option -gq "@mosaic-step" "5"
  tmux set-option -gq "@mosaic-debug" "0"
}

mosaic_register_hooks() {
  local exec hook
  exec=$(tmux show-option -gqv "@mosaic-exec")
  [[ -z "$exec" ]] && return 0

  for hook in after-split-window after-kill-pane pane-exited pane-died after-select-pane; do
    tmux set-hook -ga "$hook" "run-shell -b '$exec relayout #{window_id}'"
  done
  tmux set-hook -ga after-resize-pane \
    "run-shell -b '$exec _sync-state #{window_id}'"
}
