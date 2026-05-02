{
  description = "tmux-mosaic — composable, well-tested pane tiling for tmux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    {
      nixpkgs,
      systems,
      ...
    }:
    let
      forEachSystem =
        f: nixpkgs.lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});
    in
    {
      formatter = forEachSystem (pkgs: pkgs.nixfmt-tree);

      packages = forEachSystem (pkgs: {
        default = pkgs.tmuxPlugins.mkTmuxPlugin {
          pluginName = "mosaic";
          version = "0.1.2-dev";
          rtpFilePath = "mosaic.tmux";
          src = pkgs.lib.cleanSourceWith {
            src = ./.;
            filter =
              name: _:
              let
                base = baseNameOf name;
              in
              !(builtins.elem base [
                ".direnv"
                ".envrc"
                ".forgejo"
                ".github"
                ".gitignore"
                ".editorconfig"
                "AGENTS.md"
                "bash32-smoke.sh"
                "biome.json"
                "forgejo-release.sh"
                "flake.nix"
                "flake.lock"
                "justfile"
                "release-version.sh"
                "result"
                "tests"
              ])
              && !(pkgs.lib.hasPrefix "result-" base);
          };
        };
      });

      devShells = forEachSystem (
        pkgs:
        let
          common = [
            pkgs.biome
            pkgs.bats
            pkgs.curl
            pkgs.git
            pkgs.jq
            pkgs.parallel
            pkgs.python3
            pkgs.shellcheck
            pkgs.shfmt
            pkgs.tmux
            pkgs.just
          ];
        in
        {
          default = pkgs.mkShell { packages = common; };
          ci = pkgs.mkShell { packages = common; };
        }
      );
    };
}
