#!/usr/bin/env bash
# Pre-stow setup for ssh package
set -euo pipefail

# Create the control socket directory (ControlPath needs it)
mkdir -p ~/.ssh/sockets
chmod 700 ~/.ssh ~/.ssh/sockets
