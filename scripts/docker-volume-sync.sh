#!/bin/bash
# ==============================================================================
# SCRIPT: docker-volume-sync.sh
# DESCRIPTION: 
#   A generic utility to migrate a Docker Named Volume from a local host to a 
#   remote VM. It uses an ephemeral Alpine "sidecar" container to stream data 
#   over SSH without creating intermediate files on disk.
#
# ARGUMENTS:
#   $1 - VOLUME_NAME: The name of the Docker volume to migrate.
#   $2 - REMOTE_IP:   The IP address of the target VM.
#
# REQUIREMENTS:
#   - SSH_OPTS must be exported by the parent script (containing private keys).
#   - Docker must be installed and running on both local and remote hosts.
#   - The remote user must have 'docker' group permissions.
#
# LOGIC FLOW:
#   1. Calculate local volume size and regular file count.
#   2. Purge existing volume on remote to ensure a clean state (idempotency).
#   3. Stream 'tar' output through an SSH pipe to the remote Docker daemon.
#   4. Re-calculate remote stats and verify that the regular file count matches.
# ==============================================================================
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

# 2. Proceed with the sync (Removed -v for clean output)
echo "🚀 Streaming data to $VOLUME_NAME..."
docker run --rm -v "$VOLUME_NAME":/source alpine tar --numeric-owner -czf - -C /source . | \
$SSH_CMD "docker run --rm -i -v $VOLUME_NAME:/dest alpine tar -xzf - -C /dest"

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