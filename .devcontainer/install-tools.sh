#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update -qq
sudo apt-get install -y -qq unzip curl python3 blender xvfb

mkdir -p "$HOME/.local/bin" /workspaces/tools
if command -v godot >/dev/null 2>&1; then
  godot --version
fi
