default:
    @just --list

format:
    nix fmt -- --ci
    shfmt -d mosaic.tmux scripts tests

lint:
    shellcheck mosaic.tmux scripts/*.sh scripts/algorithms/*.sh tests/helpers.bash

test:
    bats tests/integration

build:
    nix build .#default

ci: format lint test
    @:
