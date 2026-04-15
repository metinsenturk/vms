#!/bin/bash
set -euo pipefail

REPO_DIR="$HOME/home-cloud"
APPS=(pihole traefik wud dozzle)

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
make create-network

# 5. Start each app
echo "🐳 Starting apps..."
for app in "${APPS[@]}"; do
    echo "  → Starting $app..."
    make "up-$app"
done

echo "✅ App setup complete!"
