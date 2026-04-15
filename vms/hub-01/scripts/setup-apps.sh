#!/bin/bash
set -euo pipefail

REPO_DIR="$HOME/home-cloud"
APPS=(pihole traefik wud dozzle)

run_make_with_docker_group() {
    local target="$1"

    if id -nG | grep -qw docker; then
        make "$target"
        return
    fi

    if id -nG "$USER" | grep -qw docker; then
        # Use a fresh docker-group shell so provision runs work immediately
        # after usermod -aG docker in the same Vagrant provisioning session.
        sg docker -c "cd '$REPO_DIR' && make '$target'"
        return
    fi

    echo "❌ User '$USER' is not in docker group. Re-run install-docker provisioner first."
    exit 1
}

echo "🚀 Setting up home-cloud apps..."

cd "$REPO_DIR"

# 1. Check required tools (for logging only; non-fatal)
echo "🔍 Checking required tools..."
make check-tools || true

# 3. Copy per-app .env files (only if not already present)
echo "📋 Copying app .env files..."
for app in "${APPS[@]}"; do
    env_src="apps/$app/.env.example"
    env_dst="apps/$app/.env"

    # Check if destination already exists
    if [ -f "$env_dst" ]; then
        echo "  → $env_dst already exists, skipping"
    # Check if source actually exists before copying
    elif [ -f "$env_src" ]; then
        echo "  → Copying $env_src → $env_dst"
        cp "$env_src" "$env_dst"
    else
        # Graceful skip if source is missing
        echo "  → Warning: $env_src not found, skipping"
    fi
done

# 4. Create the shared Docker network
echo "🌐 Creating Docker network..."
run_make_with_docker_group create-network

# 5. Start each app
echo "🐳 Starting apps..."
for app in "${APPS[@]}"; do
    echo "  → Starting $app..."
    run_make_with_docker_group "up-$app"
done

echo "✅ App setup complete!"
