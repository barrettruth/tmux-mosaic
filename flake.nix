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
          version = "0.1.0-dev";
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
                ".github"
                ".gitignore"
                ".editorconfig"
                ".prettierrc"
                "flake.nix"
                "flake.lock"
                "justfile"
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
            pkgs.bats
            pkgs.shellcheck
            pkgs.shfmt
            pkgs.prettier
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
