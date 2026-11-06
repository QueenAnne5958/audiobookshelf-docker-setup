#!/bin/bash

# Audiobookshelf Docker Setup Script
# Open Source Version - github.com/yourusername/audiobookshelf-docker-setup

set -e

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Error: .env file not found. Copy .env.template to .env and configure."
    exit 1
fi

echo "╔══════════════════════════════════════════════════╗"
echo "║     Audiobookshelf Docker Setup Script           ║"
echo "╚══════════════════════════════════════════════════╝"

# Create directory structure
create_directories() {
    echo "Creating directory structure..."
    mkdir -p "$ABS_CONFIG_PATH"
    mkdir -p "$ABS_METADATA_PATH"
    mkdir -p "$ABS_AUDIOBOOKS_PATH"
    mkdir -p "$ABS_PODCASTS_PATH"
    echo "✅ Directories created"
}

# Generate docker-compose.yml from template
generate_compose() {
    echo "Generating docker-compose.yml..."
    envsubst < docker/docker-compose.template.yml > docker/docker-compose.yml
    echo "✅ Docker compose file generated"
}

# Deploy Audiobookshelf
deploy_audiobookshelf() {
    echo "Deploying Audiobookshelf..."
    docker compose -f docker/docker-compose.yml up -d

    # Wait for container to be healthy
    echo "Waiting for Audiobookshelf to be ready..."
    for i in {1..30}; do
        if curl -sf http://localhost:${ABS_PORT}/ping > /dev/null 2>&1; then
            echo "✅ Audiobookshelf is running!"
            break
        fi
        echo -n "."
        sleep 2
    done
}

# Main setup flow
main() {
    echo ""
    echo "Starting Audiobookshelf setup..."
    echo "Configuration:"
    echo "  Local IP: ${LOCAL_IP}"
    echo "  Port: ${ABS_PORT}"
    echo "  Config Path: ${ABS_CONFIG_PATH}"
    echo ""

    read -p "Continue with setup? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi

    create_directories
    generate_compose
    deploy_audiobookshelf

    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║            Setup Complete!                       ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""
    echo "Access Audiobookshelf at:"
    echo "  Local: http://localhost:${ABS_PORT}"
    echo "  Network: http://${LOCAL_IP}:${ABS_PORT}"
    echo ""
    echo "Next steps:"
    echo "1. Complete initial setup in web UI"
    echo "2. Create user accounts"
    echo "3. Add your audiobook libraries"
    echo "4. Configure metadata providers"
    echo ""
    echo "For remote access, run: ./scripts/setup-remote-access.sh"
}

# Run main function
main "$@"