#!/bin/bash
# ==============================================================================
# SCRIPT: pull-volumes.sh
# DESCRIPTION: 
#   Pulls one or more Docker volumes from the remote VM to the local host.
#   Usage: ./scripts/pull-volumes.sh volume1 volume2 ...
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# 1. Setup Environment (Reusing your existing secure key logic)
export ID_KEY="$HOME/.ssh/keys/hub01_key"
export SSH_OPTS="-i $ID_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

if [ -f "$PARENT_DIR/.env" ]; then
    export $(grep -v '^#' "$PARENT_DIR/.env" | tr -d '\r' | xargs)
else
    echo "❌ Error: .env file not found."
    exit 1
fi

if [ -z "$1" ]; then
    echo "❌ Usage: ./scripts/pull-volumes.sh <volume_name1> <volume_name2> ..."
    exit 1
fi

# 2. Iterate through provided volume names
for VOLUME_NAME in "$@"; do
    echo "🔄 Pulling $VOLUME_NAME from $SERVER_IP..."

    # Create local volume if it doesn't exist
    docker volume create "$VOLUME_NAME" > /dev/null

    # REVERSED STREAM: Remote Tar (Create) -> Local Tar (Extract)
    ssh $SSH_OPTS vagrant@$SERVER_IP \
        "docker run --rm -v $VOLUME_NAME:/source alpine tar --numeric-owner -czf - -C /source ." | \
        docker run --rm -i -v "$VOLUME_NAME":/dest alpine tar -xzf - -C /dest

    if [ $? -eq 0 ]; then
        echo "✅ Successfully pulled $VOLUME_NAME"
    else
        echo "❌ Failed to pull $VOLUME_NAME"
    fi
done

echo "🎉 All requested volumes processed."