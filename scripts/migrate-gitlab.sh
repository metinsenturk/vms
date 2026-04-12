#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Create a secure folder in your WSL home
mkdir -p ~/.ssh/keys

# Copy the key from the Windows drive to WSL
cp /mnt/d/vm-home/vms/hub-01/.vagrant/machines/hub-01/hyperv/private_key ~/.ssh/keys/hub01_key

# Set the strictly required permissions (Read/Write for owner only)
chmod 600 ~/.ssh/keys/hub01_key

# Update this line in migrate-gitlab.sh
ID_KEY="$HOME/.ssh/keys/hub01_key"

# We export this so the child script (docker-volume-sync) can see it
export SSH_OPTS="-i $ID_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# 2. Load .env
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
    # Call the sync script
    bash "$SCRIPT_DIR/docker-volume-sync.sh" "$vol" "$SERVER_IP"
    if [ $? -ne 0 ]; then
        echo "❌ Migration failed at $vol"
        exit 1
    fi
done

echo "🎉 GitLab migration complete!"