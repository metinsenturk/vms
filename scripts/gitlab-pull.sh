#!/bin/bash
# ==============================================================================
# SCRIPT: gitlab-pull.sh
# DESCRIPTION:
#   Pulls all GitLab Docker volumes from the remote VM to the local host.
#   Local volumes are created automatically if they do not exist.
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

echo "🚀 GitLab pull ← $SERVER_IP"

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
