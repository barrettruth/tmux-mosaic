default:
    @just --list

format:
    nix fmt -- --ci
    shfmt -i 2 -d mosaic.tmux scripts tests
    biome format biome.json README.md .github

lint:
    shellcheck -x --source-path=SCRIPTDIR --source-path=SCRIPTDIR/scripts mosaic.tmux scripts/*.sh scripts/layouts/*.sh tests/helpers.bash

test:
    jobs="${BATS_JOBS:-$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"; \
    if [ -n "${BATS_FILTER:-}" ]; then \
      bats -j "$jobs" -f "$BATS_FILTER" tests/integration; \
    else \
      bats -j "$jobs" tests/integration; \
    fi

build:
    nix build .#default

ci: format lint test
    @:
