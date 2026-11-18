#!/usr/bin/env bash

# tmux itself is provided by the pixi environment (see pixi.toml)

# Install config
cp "$(dirname "${BASH_SOURCE[0]}")/tmux.conf" "$HOME/.tmux.conf"
