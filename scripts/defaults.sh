#!/usr/bin/env bash

mosaic_set_defaults() {
  tmux set-option -gq "@mosaic-default-algorithm" "master-stack"
  tmux set-option -gwq "@mosaic-orientation" "left"
  tmux set-option -gq "@mosaic-mfact" "50"
  tmux set-option -gq "@mosaic-step" "5"
  tmux set-option -gq "@mosaic-debug" "0"
}

mosaic_register_hooks() {
  local exec
  exec=$(tmux show-option -gqv "@mosaic-exec")
  [[ -z "$exec" ]] && return 0

  tmux set-hook -ga after-split-window \
    "run-shell -b '$exec relayout #{window_id}'"
  tmux set-hook -ga after-kill-pane \
    "run-shell -b '$exec relayout #{window_id}'"
  tmux set-hook -ga pane-exited \
    "run-shell -b '$exec relayout #{window_id}'"
  tmux set-hook -ga pane-died \
    "run-shell -b '$exec relayout #{window_id}'"
  tmux set-hook -ga after-resize-pane \
    "run-shell -b '$exec _sync-state #{window_id}'"
  tmux set-hook -ga after-select-pane \
    "run-shell -b '$exec relayout #{window_id}'"
}
