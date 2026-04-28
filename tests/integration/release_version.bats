#!/usr/bin/env bats

load '../helpers.bash'

RELEASE_SCRIPT="$REPO_ROOT/scripts/release-version.sh"

setup() {
  cat >"$BATS_TEST_TMPDIR/flake.nix" <<'EOF'
{
  packages = {
    default = {
      version = "0.1.0-dev";
    };
  };
}
EOF
}

@test "release-version: get prints the current version" {
  run env MOSAIC_FLAKE_FILE="$BATS_TEST_TMPDIR/flake.nix" "$RELEASE_SCRIPT" get
  [ "$status" -eq 0 ]
  [ "$output" = "0.1.0-dev" ]
}

@test "release-version: set rewrites the flake version" {
  run env MOSAIC_FLAKE_FILE="$BATS_TEST_TMPDIR/flake.nix" "$RELEASE_SCRIPT" set 0.1.0
  [ "$status" -eq 0 ]

  run env MOSAIC_FLAKE_FILE="$BATS_TEST_TMPDIR/flake.nix" "$RELEASE_SCRIPT" get
  [ "$status" -eq 0 ]
  [ "$output" = "0.1.0" ]
}

@test "release-version: assert-dev accepts dev versions" {
  run env MOSAIC_FLAKE_FILE="$BATS_TEST_TMPDIR/flake.nix" "$RELEASE_SCRIPT" assert-dev 0.1.0-dev
  [ "$status" -eq 0 ]
}

@test "release-version: assert-dev rejects stable versions" {
  run env MOSAIC_FLAKE_FILE="$BATS_TEST_TMPDIR/flake.nix" "$RELEASE_SCRIPT" assert-dev 0.1.0
  [ "$status" -ne 0 ]
}

@test "release-version: assert-stable accepts stable versions" {
  run env MOSAIC_FLAKE_FILE="$BATS_TEST_TMPDIR/flake.nix" "$RELEASE_SCRIPT" assert-stable 0.1.0
  [ "$status" -eq 0 ]
}

@test "release-version: base strips dev suffix" {
  run env MOSAIC_FLAKE_FILE="$BATS_TEST_TMPDIR/flake.nix" "$RELEASE_SCRIPT" base 0.1.0-dev
  [ "$status" -eq 0 ]
  [ "$output" = "0.1.0" ]
}

@test "release-version: next-patch-dev increments patch" {
  run env MOSAIC_FLAKE_FILE="$BATS_TEST_TMPDIR/flake.nix" "$RELEASE_SCRIPT" next-patch-dev 0.1.0
  [ "$status" -eq 0 ]
  [ "$output" = "0.1.1-dev" ]
}

@test "release-version: tag adds the v prefix" {
  run env MOSAIC_FLAKE_FILE="$BATS_TEST_TMPDIR/flake.nix" "$RELEASE_SCRIPT" tag 0.1.0
  [ "$status" -eq 0 ]
  [ "$output" = "v0.1.0" ]
}

@test "release-version: nightly-tag embeds the dev version and short sha" {
  run env MOSAIC_FLAKE_FILE="$BATS_TEST_TMPDIR/flake.nix" "$RELEASE_SCRIPT" nightly-tag 0123456789abcdef0123456789abcdef01234567
  [ "$status" -eq 0 ]
  [ "$output" = "nightly-0.1.0-dev-0123456" ]
}

@test "release-version: nightly-tag lowercases mixed-case shas" {
  run env MOSAIC_FLAKE_FILE="$BATS_TEST_TMPDIR/flake.nix" "$RELEASE_SCRIPT" nightly-tag AbCdEf0123456789abcdef0123456789ABCDEF01
  [ "$status" -eq 0 ]
  [ "$output" = "nightly-0.1.0-dev-abcdef0" ]
}

@test "release-version: nightly-tag rejects stable versions" {
  run env MOSAIC_FLAKE_FILE="$BATS_TEST_TMPDIR/flake.nix" "$RELEASE_SCRIPT" nightly-tag 0.1.0 0123456789abcdef0123456789abcdef01234567
  [ "$status" -ne 0 ]
}
