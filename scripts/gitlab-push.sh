#!/bin/bash
# ==============================================================================
# SCRIPT: gitlab-push.sh
# DESCRIPTION:
#   Pushes all GitLab Docker volumes from the local host to the remote VM.
#   The local GitLab containers MUST be stopped before running this script
#   to prevent database corruption during the cold migration.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/volume-lib.sh
source "$SCRIPT_DIR/lib/volume-lib.sh"

readonly VOLUMES=(
    "home_gitlab_data"
    "home_gitlab_config"
    "home_gitlab_logs"
)

# SERVER_IP must be exported by the caller (e.g. export SERVER_IP=192.168.1.138)
lib_init

echo "🚀 GitLab push → $SERVER_IP"
echo "⚠️  Ensure local GitLab containers are STOPPED before continuing."
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
