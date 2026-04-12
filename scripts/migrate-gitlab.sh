#!/bin/bash
# ==============================================================================
# SCRIPT: migrate-gitlab.sh
# DESCRIPTION: 
#   Orchestrates the migration of a GitLab instance's persistent storage. 
#   Specifically targets the Data, Config, and Logs volumes. This script handles 
#   the bridging between Windows/WSL and the Linux VM environment.
#
# USAGE:
#   Run from the project root: ./scripts/migrate-gitlab.sh
#
# RELEVANT VOLUMES:
#   - home_gitlab_data:   Repositories and database files.
#   - home_gitlab_config: SSH keys and gitlab.rb settings.
#   - home_gitlab_logs:   Application and system logs.
#
# LOGIC FLOW:
#   1. Securely migrates the Hyper-V private key from NTFS to WSL (~/.ssh/keys)
#      to resolve permission 0777 issues.
#   2. Loads environment variables (SERVER_IP) from the project .env file.
#   3. Iterates through GitLab-specific volumes and calls docker-volume-sync.sh.
#   4. Halts execution if any volume fails verification.
#
# PRE-REQUISITES:
#   - Local GitLab containers MUST be stopped (Cold Migration) to prevent 
#     database corruption.
# ==============================================================================
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