#!/usr/bin/env bash

_layout_fibonacci_variant() { printf '%s\n' "dwindle"; }

_layout_relayout() { _mosaic_fibonacci_relayout "$@"; }
_layout_new_pane() { _mosaic_fibonacci_new_pane "$1"; }
_layout_promote() { _mosaic_fibonacci_promote; }
_layout_resize_master() { _mosaic_fibonacci_resize_master "$@"; }
_layout_sync_state() { _mosaic_fibonacci_sync_state "$1"; }
