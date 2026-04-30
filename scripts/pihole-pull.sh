#!/bin/bash
# ==============================================================================
# SCRIPT: pihole-pull.sh
# DESCRIPTION:
#   Pulls the Pi-hole Docker volume from the remote VM to the local host.
#   Local volume is created automatically if it does not exist.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/volume-lib.sh
source "$SCRIPT_DIR/lib/volume-lib.sh"

readonly VOLUMES=(
    "home_pihole_data"
)

# SERVER_IP must be exported by the caller (e.g. export SERVER_IP=192.168.1.138)
lib_init

echo "🚀 Pi-hole pull ← $SERVER_IP"

failed=()

for vol in "${VOLUMES[@]}"; do
    if volume_pull "$vol" && volume_verify "$vol" "remote" "local"; then
        echo "✅ $vol"
    else
        echo "❌ $vol"
        failed+=("$vol")
    fi
done

print_summary "${failed[@]}"
