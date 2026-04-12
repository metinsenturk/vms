#!/bin/bash
# Usage: ./docker-volume-sync.sh <volume_name> <remote_ip>

VOLUME_NAME=$1
REMOTE_IP=$2

if [ -z "$VOLUME_NAME" ] || [ -z "$REMOTE_IP" ]; then
    echo "Usage: $0 <volume_name> <remote_ip>"
    exit 1
fi

get_volume_size() {
    local vol=$1
    local target=$2
    if [ "$target" == "local" ]; then
        docker run --rm -v "$vol":/data alpine du -sb /data | awk '{print $1}'
    else
        ssh vagrant@"$REMOTE_IP" "docker run --rm -v $vol:/data alpine du -sb /data" | awk '{print $1}'
    fi
}

echo "🔄 Syncing $VOLUME_NAME..."

# 1. Capture local size before sync
LOCAL_SIZE=$(get_volume_size "$VOLUME_NAME" "local")

# 2. Ensure remote volume exists
ssh vagrant@"$REMOTE_IP" "docker volume create $VOLUME_NAME" > /dev/null

# 3. Stream data
docker run --rm -v "$VOLUME_NAME":/source alpine tar --numeric-owner -czf - -C /source . | \
ssh vagrant@"$REMOTE_IP" "docker run --rm -i -v $VOLUME_NAME:/dest alpine tar -xzf - -C /dest"

# 4. Verification
REMOTE_SIZE=$(get_volume_size "$VOLUME_NAME" "remote")

echo "📊 Verification for $VOLUME_NAME:"
echo "   Local:  $LOCAL_SIZE bytes"
echo "   Remote: $REMOTE_SIZE bytes"

if [ "$LOCAL_SIZE" -eq "$REMOTE_SIZE" ] && [ "$LOCAL_SIZE" -gt 0 ]; then
    echo "✅ Success: $VOLUME_NAME (Exact Match)"
else
    # Small delta allowed if you prefer, but with containers stopped, it should be exact.
    echo "⚠️  Warning: $VOLUME_NAME size mismatch or empty volume!"
    exit 1
fi