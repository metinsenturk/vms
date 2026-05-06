#!/bin/bash
set -euo pipefail

MARKER="/var/tmp/ollama-install.ok"

if [ -f "$MARKER" ]; then
  echo "Ollama already installed, skipping."
  exit 0
fi

echo "==> Installing curl (if missing)..."
sudo apt-get update -qq
sudo apt-get install -y -qq curl

echo "==> Downloading and installing Ollama..."
curl -fsSL https://ollama.com/install.sh | sudo sh

# The official installer creates and enables ollama.service under the ollama user.
# Ensure it is enabled and running.
sudo systemctl enable ollama
sudo systemctl start ollama

touch "$MARKER"
echo "==> Ollama installed and service started."
