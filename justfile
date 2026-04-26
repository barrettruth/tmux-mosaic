default:
    @just --list

format:
    nix fmt -- --ci
    shfmt -i 2 -d mosaic.tmux scripts tests
    biome format biome.json README.md .github

lint:
    shellcheck -x --source-path=SCRIPTDIR --source-path=SCRIPTDIR/scripts mosaic.tmux scripts/*.sh scripts/layouts/*.sh tests/helpers.bash

test:
    bats tests/integration/*.bats

build:
    nix build .#default

ci: format lint test
    @:
