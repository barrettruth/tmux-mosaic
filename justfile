default:
    @just --list

nixfmt:
    nix fmt -- --ci

shfmt:
    shfmt -i 2 -d mosaic.tmux scripts tests

shellcheck:
    shellcheck -x --source-path=SCRIPTDIR --source-path=SCRIPTDIR/scripts mosaic.tmux scripts/*.sh scripts/algorithms/*.sh tests/helpers.bash

format: nixfmt shfmt
    @:

lint: shellcheck
    @:

test:
    bats tests/integration/*.bats

build:
    nix build .#default

ci: format lint test
    @:
