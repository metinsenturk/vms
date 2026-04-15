#!/bin/bash
# ==============================================================================
# LIBRARY: volume-lib.sh
# DESCRIPTION:
#   Shared library for Docker volume operations between a local host and a
#   remote VM over SSH. Source this file, then call lib_init before any other
#   function.
#
# EXPORTED GLOBALS (after lib_init):
#   SSH_OPTS   - SSH flags for all remote calls (key auth, no host checking)
#   SERVER_IP  - Remote VM IP loaded from .env
#   SSH_CMD    - Full SSH command prefix for the vagrant user
# ==============================================================================

# Guard against double-sourcing
[[ -n "${_VOLUME_LIB_LOADED:-}" ]] && return 0
readonly _VOLUME_LIB_LOADED=1

# Path to the SSH key used for the hub-01 VM
readonly _DEFAULT_KEY="$HOME/.ssh/keys/hub01_key"

# ==============================================================================
# lib_init
# Sets up the SSH key, loads .env, and exports SSH_OPTS / SERVER_IP / SSH_CMD.
#
# Arguments:
#   $1 - Absolute path to the project root (parent of scripts/)
# ==============================================================================
lib_init() {
    local project_root="$1"
    local env_file="$project_root/.env"
    local key_src="/mnt/d/vm-home/vms/hub-01/.vagrant/machines/hub-01/hyperv/private_key"

    # Ensure the secure key directory exists
    mkdir -p "$HOME/.ssh/keys"

    # Copy the Vagrant private key to a WSL-safe location and lock permissions
    cp "$key_src" "$_DEFAULT_KEY"
    chmod 600 "$_DEFAULT_KEY"

    # Load environment variables, stripping comments and Windows line endings
    if [[ ! -f "$env_file" ]]; then
        echo "❌ Error: .env not found at $env_file" >&2
        return 1
    fi

    set -a
    # shellcheck disable=SC1090
    source <(grep -v '^#' "$env_file" | tr -d '\r')
    set +a

    if [[ -z "${SERVER_IP:-}" ]]; then
        echo "❌ Error: SERVER_IP not defined in $env_file" >&2
        return 1
    fi

    export SSH_OPTS="-i $_DEFAULT_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    export SSH_CMD="ssh $SSH_OPTS vagrant@$SERVER_IP"
}

# ==============================================================================
# volume_stats
# Prints two lines to stdout: byte size, then regular file count for a volume.
#
# Arguments:
#   $1 - Volume name
#   $2 - Location: "local" or "remote"
# ==============================================================================
volume_stats() {
    local vol="$1"
    local location="$2"

    local inner_cmd="docker run --rm -v $vol:/data alpine sh -c"
    local stat_script="'du -sb /data | awk \"{print \\\$1}\"; find /data -type f | wc -l'"

    if [[ "$location" == "local" ]]; then
        eval "$inner_cmd $stat_script"
    else
        $SSH_CMD "$inner_cmd $stat_script"
    fi
}

# ==============================================================================
# volume_push
# Streams a local Docker volume to the remote VM.
# Purges the remote volume first to ensure a clean, idempotent transfer.
#
# Arguments:
#   $1 - Volume name
# ==============================================================================
volume_push() {
    local vol="$1"

    echo "🔄 Pushing $vol → $SERVER_IP..."

    # Purge existing remote volume for a clean state
    $SSH_CMD "docker volume rm -f $vol > /dev/null 2>&1 || true"
    $SSH_CMD "docker volume create $vol" > /dev/null

    # Stream: local tar (create) → SSH pipe → remote tar (extract)
    docker run --rm -v "$vol":/source alpine \
        tar --numeric-owner -czf - -C /source . \
    | $SSH_CMD "docker run --rm -i -v $vol:/dest alpine tar -xzf - -C /dest"
}

# ==============================================================================
# volume_pull
# Streams a remote Docker volume from the VM to the local host.
# Creates the local volume if it does not exist.
#
# Arguments:
#   $1 - Volume name
# ==============================================================================
volume_pull() {
    local vol="$1"

    echo "🔄 Pulling $vol ← $SERVER_IP..."

    # Create local volume if absent (idempotent)
    docker volume create "$vol" > /dev/null

    # Stream: remote tar (create) → SSH pipe → local tar (extract)
    $SSH_CMD "docker run --rm -v $vol:/source alpine tar --numeric-owner -czf - -C /source ." \
    | docker run --rm -i -v "$vol":/dest alpine tar -xzf - -C /dest
}

# ==============================================================================
# volume_verify
# Compares file counts between the source and destination of a transfer.
# Tolerates a difference of up to 2 files (Alpine sidecar artefacts).
# Returns 0 on pass, 1 on mismatch.
#
# Arguments:
#   $1 - Volume name
#   $2 - Source location:      "local" or "remote"
#   $3 - Destination location: "local" or "remote"
# ==============================================================================
volume_verify() {
    local vol="$1"
    local src_loc="$2"
    local dst_loc="$3"

    local src_stats dst_stats
    src_stats=($(volume_stats "$vol" "$src_loc"))
    dst_stats=($(volume_stats "$vol" "$dst_loc"))

    local src_size="${src_stats[0]}" src_count="${src_stats[1]}"
    local dst_size="${dst_stats[0]}" dst_count="${dst_stats[1]}"

    local diff=$(( src_count - dst_count ))
    local abs_diff="${diff#-}"

    echo "📊 $vol — src(${src_loc}): ${src_size}B / ${src_count} files" \
         "| dst(${dst_loc}): ${dst_size}B / ${dst_count} files"

    if [[ "$abs_diff" -le 2 ]]; then
        return 0
    else
        echo "⚠️  File count mismatch: src=$src_count dst=$dst_count" >&2
        return 1
    fi
}

# ==============================================================================
# print_summary
# Prints a final pass/fail report.
# Returns 1 if any failures are present.
#
# Arguments:
#   $@ - Names of volumes that FAILED (pass an empty list for full success)
# ==============================================================================
print_summary() {
    local -a failed=("$@")

    echo ""
    echo "=============================="
    if [[ "${#failed[@]}" -eq 0 ]]; then
        echo "🎉 ALL VOLUMES TRANSFERRED SUCCESSFULLY"
    else
        echo "❌ TRANSFER INCOMPLETE"
        echo "   Failed volumes: ${failed[*]}"
        echo "=============================="
        return 1
    fi
    echo "=============================="
}
