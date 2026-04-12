#!/bin/bash

# 1. Load the variables from your root .env
# We use 'sed' to strip quotes if they exist in the .env file
CONF_FILE="$HOME/home-cloud/apps/pihole/dnsmasq.d/99-wildcard.conf"
ENV_FILE="$HOME/home-cloud/.env"

if [ -f "$ENV_FILE" ]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo "Error: .env file not found at $ENV_FILE"
    exit 1
fi

# 2. Ensure the directory exists
mkdir -p "$(dirname "$CONF_FILE")"

# 3. Overwrite the file with the fresh configuration
# This ensures that if you change SERVER_IP in .env, the config updates
echo "address=/${DOMAIN}/${SERVER_IP}" > "$CONF_FILE"
echo "Success: $CONF_FILE updated with address=/${DOMAIN}/${SERVER_IP}"

# 4. Verification: Check the VM file and Container file
echo "VM file content:"
cat "$CONF_FILE"
echo "Container file content:"
docker exec -it pihole cat /etc/dnsmasq.d/99-wildcard.conf
echo "If the above content matches, the wildcard DNS is set up correctly."

# 5. Restart the pihole container to apply changes
# Only restart if the container is already running
if [ "$(docker ps -q -f name=pihole)" ]; then
    docker restart pihole
fi