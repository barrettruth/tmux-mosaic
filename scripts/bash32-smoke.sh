#!/usr/bin/env bash

set -euo pipefail

for f in mosaic.tmux scripts/*.sh scripts/layouts/*.sh tests/helpers.bash; do
  bash -n "$f"
done

d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT

cat >"$d/flake.nix" <<'EOF'
{
  packages = {
    default = {
      version = "0.1.0-dev";
    };
  };
}
EOF

out=$(MOSAIC_FLAKE_FILE="$d/flake.nix" scripts/release-version.sh nightly-tag AbCdEf0123456789abcdef0123456789ABCDEF01)
[ "$out" = "nightly-0.1.0-dev-abcdef0" ]
