#!/bin/bash

# 1. Get the absolute path of the scripts directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# 2. Load .env from the parent directory (vm-home)
if [ -f "$PARENT_DIR/.env" ]; then
    # Clean and export variables
    export $(grep -v '^#' "$PARENT_DIR/.env" | tr -d '\r' | xargs)
else
    echo "❌ Error: .env file not found at $PARENT_DIR/.env"
    exit 1
fi

if [ -z "$SERVER_IP" ]; then
    echo "❌ Error: SERVER_IP not found in .env"
    exit 1
fi

echo "🚀 Starting GitLab Migration to $SERVER_IP..."
echo "⚠️  Ensure local GitLab is STOPPED."
read -p "Press [Enter] to begin..."

VOLUMES=("home_gitlab_data" "home_gitlab_config" "home_gitlab_logs")

for vol in "${VOLUMES[@]}"; do
    "$SCRIPT_DIR/docker-volume-sync.sh" "$vol" "$SERVER_IP"
    if [ $? -ne 0 ]; then
        echo "❌ Migration failed at $vol"
        exit 1
    fi
done

echo "🎉 GitLab migration complete!"