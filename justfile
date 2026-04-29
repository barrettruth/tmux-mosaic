default:
    @just --list

format:
    nix fmt -- --ci
    shfmt -i 2 -d mosaic.tmux scripts tests
    biome format biome.json README.md .forgejo .github

lint:
    shellcheck -x --source-path=SCRIPTDIR --source-path=SCRIPTDIR/scripts mosaic.tmux scripts/*.sh scripts/layouts/*.sh tests/helpers.bash

test:
    jobs="${BATS_JOBS:-$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"; \
    if [ -n "${BATS_FILTER:-}" ]; then \
      bats -j "$jobs" -f "$BATS_FILTER" tests/integration; \
    else \
      bats -j "$jobs" tests/integration; \
    fi

test-one filter:
    BATS_FILTER='{{filter}}' just test

test-file file:
    jobs="${BATS_JOBS:-$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"; \
    bats -j "$jobs" "tests/integration/{{file}}"

test-new-pane:
    jobs="${BATS_JOBS:-$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"; \
    bats -j "$jobs" tests/integration/new_pane_fast_paths.bats tests/integration/new_pane_acceptance.bats tests/integration/grid.bats tests/integration/monocle.bats

build:
    nix build .#default

ci: format lint test
    @:
