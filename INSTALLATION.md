# Installation

`tmux-mosaic` supports TPM, manual, and nix installs. It requires tmux 3.2+.

Mosaic installs no default keybindings. It sets `@mosaic-exec` so your own
bindings work across install methods.

## TPM

Add mosaic to your tmux config:

```tmux
set -g @plugin 'barrettruth/tmux-mosaic'
```

Install plugins with `prefix + I` if you use TPM.

## Manual

Clone the repo somewhere tmux can reach it:

```sh
git clone https://github.com/barrettruth/tmux-mosaic ~/.config/tmux/plugins/tmux-mosaic
```

Source the plugin from your tmux config:

```tmux
run-shell ~/.config/tmux/plugins/tmux-mosaic/mosaic.tmux
```

## Nix

Add the flake input:

```nix
inputs.tmux-mosaic.url = "github:barrettruth/tmux-mosaic";
```

Source the packaged plugin from your tmux wrapper config:

```tmux
run-shell ${tmux-mosaic.packages.${system}.default}/share/tmux-plugins/mosaic/mosaic.tmux
```

## After installing

Reload tmux if it is already running:

```sh
tmux source-file ~/.tmux.conf
```

Enable mosaic on the current window:

```tmux
set-option -wq @mosaic-enabled 1
```

Optional example bindings:

```tmux
bind Enter run '#{E:@mosaic-exec} promote'
bind -r , run '#{E:@mosaic-exec} resize-master -5'
bind -r . run '#{E:@mosaic-exec} resize-master +5'
bind T run '#{E:@mosaic-exec} toggle'
```

For focus movement, swapping, and zoom, keep using stock tmux commands. For the
algorithm reference, see [docs/algorithms](docs/algorithms/README.md).
