#!/usr/bin/env bash

algo_relayout() { mosaic_relayout_simple even-horizontal "${1:-}"; }

algo_toggle() { mosaic_toggle_window algo_relayout; }
