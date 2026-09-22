#!/bin/bash

# Install dependencies
sudo apt update && sudo apt -y install tmux

# Install config
cp $(pwd)/tmux.conf $HOME/.tmux.conf
