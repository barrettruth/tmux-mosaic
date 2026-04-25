default:
    @just --list

format:
    nix fmt -- --ci
    shfmt -i 2 -d mosaic.tmux scripts tests
    prettier --check .

lint:
    shellcheck -x --source-path=SCRIPTDIR --source-path=SCRIPTDIR/scripts mosaic.tmux scripts/*.sh scripts/algorithms/*.sh tests/helpers.bash

test:
    bats tests/integration/*.bats

build:
    nix build .#default

ci: format lint test
    @:
