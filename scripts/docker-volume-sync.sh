#!/bin/bash
# Usage: ./docker-volume-sync.sh <volume_name> <remote_ip>

VOLUME_NAME=$1
REMOTE_IP=$2

# Ensure we use the exported SSH_OPTS from the parent script
SSH_CMD="ssh $SSH_OPTS vagrant@$REMOTE_IP"

get_volume_size() {
    local vol=$1
    local target=$2
    
    # We use -type f to count only regular files, ignoring sockets, pipes, and directories.
    # We use du -sb to get the apparent size in bytes.
    local cmd="docker run --rm -v $vol:/data alpine sh -c 'du -sb /data | awk \"{print \\\$1}\"; find /data -type f | wc -l'"
    
    if [ "$target" == "local" ]; then
        # Capture local stats (Size and File Count)
        eval "$cmd"
    else
        # Capture remote stats via SSH using your secure key
        $SSH_CMD "$cmd"
    fi
}

echo "🔄 Syncing $VOLUME_NAME..."

LOCAL_SIZE=$(get_volume_size "$VOLUME_NAME" "local")

# 1. Ensure remote volume exists (using the key)
# 1. Force delete and recreate the volume to ensure it's empty
$SSH_CMD "docker volume rm -f $VOLUME_NAME > /dev/null 2>&1 || true"
$SSH_CMD "docker volume create $VOLUME_NAME" > /dev/null

# 2. Proceed with the sync as before
echo "🚀 Streaming data to $VOLUME_NAME..."
docker run --rm -v "$VOLUME_NAME":/source alpine tar --numeric-owner -czvf - -C /source . | \
$SSH_CMD "docker run --rm -i -v $VOLUME_NAME:/dest alpine tar -xzvf - -C /dest"

# 3. Verification
# Capture output (which now has two lines: size and count)
LOCAL_STATS=($(get_volume_size "$VOLUME_NAME" "local"))
REMOTE_STATS=($(get_volume_size "$VOLUME_NAME" "remote"))

LOCAL_SIZE=${LOCAL_STATS[0]}
LOCAL_COUNT=${LOCAL_STATS[1]}
REMOTE_SIZE=${REMOTE_STATS[0]}
REMOTE_COUNT=${REMOTE_STATS[1]}

echo "📊 Verification for $VOLUME_NAME:"
echo "   Local:  $LOCAL_SIZE bytes ($LOCAL_COUNT files)"
echo "   Remote: $REMOTE_SIZE bytes ($REMOTE_COUNT files)"

# Check if file count matches (allowing for 1-2 system files difference)
COUNT_DIFF=$((LOCAL_COUNT - REMOTE_COUNT))
abs_count_diff=${COUNT_DIFF#-}

if [ "$abs_count_diff" -le 2 ]; then
    echo "✅ Success: $VOLUME_NAME (File counts match)"
else
    echo "⚠️  Warning: File count mismatch! Local: $LOCAL_COUNT, Remote: $REMOTE_COUNT"
    exit 1
fi