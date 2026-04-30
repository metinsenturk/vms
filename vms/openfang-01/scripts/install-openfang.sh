#!/bin/bash
set -euo pipefail

MARKER="/var/tmp/openfang-install.ok"
SERVICE_FILE="/etc/systemd/system/openfang.service"
OPENFANG_BIN="$HOME/.local/bin/openfang"

# Idempotency guard
if [ -f "$MARKER" ]; then
  echo "OpenFang already installed, skipping."
  exit 0
fi

echo "==> Installing dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq curl

echo "==> Downloading and installing OpenFang..."
curl -fsSL https://openfang.sh/install | sh

echo "==> Initialising OpenFang..."
"$OPENFANG_BIN" init

echo "==> Installing systemd service..."
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=OpenFang Agent OS
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=vagrant
ExecStart=${OPENFANG_BIN} start
Restart=on-failure
RestartSec=5
Environment=HOME=/home/vagrant

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable openfang
sudo systemctl start openfang

echo "==> OpenFang service started. Dashboard available at http://$(hostname -I | awk '{print $1}'):4200"

touch "$MARKER"
echo "==> Done."
