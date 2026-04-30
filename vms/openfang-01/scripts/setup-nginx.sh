#!/bin/bash
set -euo pipefail

MARKER="/var/tmp/nginx-openfang.ok"

if [ -f "$MARKER" ]; then
  echo "nginx reverse proxy already configured, skipping."
  exit 0
fi

echo "==> Installing nginx..."
sudo apt-get update -qq
sudo apt-get install -y -qq nginx

echo "==> Configuring reverse proxy for OpenFang..."
sudo tee /etc/nginx/sites-available/openfang > /dev/null <<'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass         http://127.0.0.1:4200;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection "upgrade";
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 3600;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/openfang /etc/nginx/sites-enabled/openfang
sudo rm -f /etc/nginx/sites-enabled/default

sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx

touch "$MARKER"
echo "==> nginx reverse proxy ready. OpenFang accessible at http://$(hostname -I | awk '{print $1}')"
