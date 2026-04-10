#!/bin/sh
set -eu

marker_file="/var/tmp/provision-test.ok"
log_file="/var/tmp/provision-test.log"

# Idempotent test provisioning: write marker once, always append a timestamp log.
if [ ! -f "$marker_file" ]; then
  sudo touch "$marker_file"
  sudo chmod 644 "$marker_file"
fi

echo "provisioned_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" | sudo tee -a "$log_file" >/dev/null

echo "Provision test complete"
ls -l "$marker_file" "$log_file"
