#!/bin/bash

# Load SERVER_IP from .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "❌ Error: .env file not found."
    exit 1
fi

echo "🚀 Starting GitLab Migration..."
echo "⚠️  Ensure local GitLab is STOPPED."
read -p "Press enter to begin..."

# Define the volumes we want to move
VOLUMES=("home_gitlab_data" "home_gitlab_config" "home_gitlab_logs")

for vol in "${VOLUMES[@]}"; do
    ./docker-volume-sync.sh "$vol" "$SERVER_IP"
done

echo "🎉 GitLab migration complete!"