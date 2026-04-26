#!/usr/bin/env bash

algo_fibonacci_variant() { printf '%s\n' "dwindle"; }

algo_relayout() { mosaic_fibonacci_relayout "$@"; }
algo_toggle() { mosaic_toggle_window algo_relayout; }
algo_promote() { mosaic_fibonacci_promote; }
algo_resize_master() { mosaic_fibonacci_resize_master "$@"; }
algo_sync_state() { mosaic_fibonacci_sync_state "$1"; }
