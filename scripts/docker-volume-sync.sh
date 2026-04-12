#!/bin/bash
# Usage: ./docker-volume-sync.sh <volume_name> <remote_ip>

VOLUME_NAME=$1
REMOTE_IP=$2

# Ensure we use the exported SSH_OPTS from the parent script
SSH_CMD="ssh $SSH_OPTS vagrant@$REMOTE_IP"

get_volume_size() {
    local vol=$1
    local target=$2
    if [ "$target" == "local" ]; then
        docker run --rm -v "$vol":/data alpine du -sb /data | awk '{print $1}'
    else
        # Use the key-enabled SSH command here
        $SSH_CMD "docker run --rm -v $vol:/data alpine du -sb /data" | awk '{print $1}'
    fi
}

echo "🔄 Syncing $VOLUME_NAME..."

LOCAL_SIZE=$(get_volume_size "$VOLUME_NAME" "local")

# 1. Ensure remote volume exists (using the key)
$SSH_CMD "docker volume create $VOLUME_NAME" > /dev/null

# 2. Stream data (using the key)
docker run --rm -v "$VOLUME_NAME":/source alpine tar --numeric-owner -czvf - -C /source . | \
$SSH_CMD "docker run --rm -i -v $VOLUME_NAME:/dest alpine tar -xzvf - -C /dest"

# 3. Verification
REMOTE_SIZE=$(get_volume_size "$VOLUME_NAME" "remote")

echo "📊 Verification for $VOLUME_NAME:"
echo "   Local:  $LOCAL_SIZE bytes"
echo "   Remote: $REMOTE_SIZE bytes"

if [ "$LOCAL_SIZE" -eq "$REMOTE_SIZE" ] && [ "$LOCAL_SIZE" -gt 0 ]; then
    echo "✅ Success: $VOLUME_NAME"
else
    echo "⚠️  Warning: Size mismatch! Check logs."
    exit 1
fi