#!/usr/bin/env bash

_mosaic_set_defaults() {
  tmux set-option -gwq "@mosaic-orientation" "left"
  tmux set-option -gwq "@mosaic-nmaster" "1"
  tmux set-option -gwq "@mosaic-auto-apply" "full"
  tmux set-option -gq "@mosaic-mfact" "50"
  tmux set-option -gq "@mosaic-step" "5"
  tmux set-option -gq "@mosaic-debug" "0"
}

_mosaic_hook_is_ours() {
  local line="$1"
  [[ "$line" == *mosaic* ]] || return 1
  case "$line" in
  *"scripts/ops.sh relayout #{window_id}"* | \
    *"scripts/ops.sh _sync-state #{window_id}"* | \
    *"scripts/ops.sh _on-set-option #{hook_argument_0} #{window_id}"*)
    return 0
    ;;
  esac
  return 1
}

_mosaic_unregister_hooks() {
  local hook="$1" line
  local -a hooks=()
  while IFS= read -r line; do
    [[ "$line" == *'['*']'* ]] || continue
    _mosaic_hook_is_ours "$line" || continue
    hooks+=("${line%% *}")
  done < <(tmux show-hooks -g "$hook" 2>/dev/null || true)

  local i
  for ((i = ${#hooks[@]} - 1; i >= 0; i--)); do
    tmux set-hook -gu "${hooks[i]}"
  done
}

_mosaic_register_hooks() {
  local exec hook _layout_option_filter
  exec=$(tmux show-option -gqv "@mosaic-exec")
  [[ -z "$exec" ]] && return 0

  for hook in after-split-window after-kill-pane pane-exited pane-died after-select-pane after-resize-pane after-set-option; do
    _mosaic_unregister_hooks "$hook"
  done

  for hook in after-split-window after-kill-pane pane-exited pane-died after-select-pane; do
    tmux set-hook -ga "$hook" "run-shell -b '$exec relayout #{window_id}'"
  done
  tmux set-hook -ga after-resize-pane \
    "run-shell -b '$exec _sync-state #{window_id}'"

  _layout_option_filter='#{||:#{||:#{m:@mosaic-layout,#{hook_argument_0}},#{m:@mosaic-orientation,#{hook_argument_0}}},#{||:#{m:@mosaic-nmaster,#{hook_argument_0}},#{m:@mosaic-mfact,#{hook_argument_0}}}}'
  tmux set-hook -ga after-set-option \
    "if-shell -bF '$_layout_option_filter' \"run-shell -b '$exec _on-set-option #{hook_argument_0} #{window_id}'\""
}
