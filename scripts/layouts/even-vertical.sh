#!/usr/bin/env bash

_layout_relayout() { _mosaic_relayout_simple even-vertical "${1:-}"; }

_layout_toggle() { _mosaic_toggle_window; }
_layout_new_pane() { _mosaic_new_pane_append "$1"; }
