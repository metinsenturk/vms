#!/usr/bin/env bash
set -euo pipefail

# this script fixes the systemd-resolved configuration to ensure proper DNS resolution in the VM
# it should be run as part of the provisioning process to ensure the VM has correct DNS settings

echo "Disabling systemd-resolved to free up Port 53..."
sudo systemctl disable --now systemd-resolved

echo "Removing existing resolv.conf symlink..."
sudo rm -f /etc/resolv.conf

echo "Creating static resolv.conf with temporary upstream DNS..."
# We use 1.1.1.1 so the VM can still pull Docker images 
# until Pi-hole is actually up and running.
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf