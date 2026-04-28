#!/usr/bin/env bash

_layout_relayout() { _mosaic_relayout_simple even-vertical "${1:-}"; }

_layout_new_pane() {
  _mosaic_new_pane_split_or_append "${1:-}" "$(_mosaic_window_last_pane "${1:-}")"
}
