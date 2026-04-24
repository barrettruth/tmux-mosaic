default:
    @just --list

format:
    nix fmt -- --ci
    shfmt -d mosaic.tmux scripts tests

lint:
    shellcheck -x --source-path=SCRIPTDIR --source-path=SCRIPTDIR/scripts mosaic.tmux scripts/*.sh scripts/algorithms/*.sh tests/helpers.bash

test:
    bats tests/integration

build:
    nix build .#default

ci: format lint test
    @:
