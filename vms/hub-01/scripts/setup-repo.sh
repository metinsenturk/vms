#!/bin/bash
REPO_URL="https://github.com/metinsenturk/home-cloud.git"
DEST_DIR="$HOME/home-cloud"
ENV_FILE="$DEST_DIR/.env"

echo "🚀 Bootstrapping home-cloud repository..."

# 1. Clone if it doesn't exist, pull if it does
if [ ! -d "$DEST_DIR" ]; then
    git clone "$REPO_URL" "$DEST_DIR"
else
    echo "Directory exists, pulling latest changes..."
    cd "$DEST_DIR" && git pull
fi

# 2. Setup the .env file and inject IP if missing
if [ ! -f "$ENV_FILE" ]; then
    echo "Creating .env from example..."
    cp "$DEST_DIR/.env.example" "$ENV_FILE"
    
    echo "💉 Injecting SERVER_IP: $SERVER_IP"
    # Note: We use the $SERVER_IP variable passed from Vagrant/Shell
    sed -i "s|^SERVER_IP=.*|SERVER_IP=$SERVER_IP|" "$ENV_FILE"
else
    echo "📄 .env file already exists. Skipping injection to preserve manual changes."
fi

# 3. Ensure the current user owns the folder
sudo chown -R $USER:$USER "$DEST_DIR"

echo "✅ Repository is ready at $DEST_DIR"