#!/bin/bash
# Usage: ./sync-volume.sh [volume_name] [remote_ip]

VOLUME_NAME=$1
REMOTE_IP=$2

if [ -z "$VOLUME_NAME" ] || [ -z "$REMOTE_IP" ]; then
    echo "Usage: ./sync-volume.sh <volume_name> <remote_ip>"
    exit 1
fi

echo "🔄 Starting migration of $VOLUME_NAME..."

# 1. Ensure remote volume exists
ssh vagrant@$REMOTE_IP "docker volume create $VOLUME_NAME"

# 2. Stream data using numeric IDs to prevent permission drift
docker run --rm -v $VOLUME_NAME:/source alpine tar --numeric-owner -czf - -C /source . | \
ssh vagrant@$REMOTE_IP "docker run --rm -i -v $VOLUME_NAME:/dest alpine tar -xzf - -C /dest"

if [ $? -eq 0 ]; then
    echo "✅ Success: $VOLUME_NAME"
else
    echo "❌ Error: $VOLUME_NAME"
    exit 1
fi

echo "✅ Migration of $VOLUME_NAME to $REMOTE_IP finished!"