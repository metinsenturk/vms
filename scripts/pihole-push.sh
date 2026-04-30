#!/bin/bash
# ==============================================================================
# SCRIPT: pihole-push.sh
# DESCRIPTION:
#   Pushes the Pi-hole Docker volume from the local host to the remote VM.
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

echo "🚀 Pi-hole push → $SERVER_IP"
echo "⚠️  Ensure local Pi-hole container is STOPPED before continuing."
read -rp "Press [Enter] to begin or Ctrl+C to abort..."

failed=()

for vol in "${VOLUMES[@]}"; do
    if volume_push "$vol" && volume_verify "$vol" "local" "remote"; then
        echo "✅ $vol"
    else
        echo "❌ $vol"
        failed+=("$vol")
    fi
done

print_summary "${failed[@]}"
