#!/bin/bash

# Cloudflare Tunnel Setup for Audiobookshelf
# Configures public access via Cloudflare

set -e

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Error: .env file not found."
    exit 1
fi

echo "╔══════════════════════════════════════════════════╗"
echo "║     Cloudflare Tunnel Setup for Audiobookshelf   ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# Check if cloudflared is installed
install_cloudflared() {
    if ! command -v cloudflared &> /dev/null; then
        echo "Installing cloudflared..."
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
        sudo dpkg -i cloudflared-linux-amd64.deb
        rm cloudflared-linux-amd64.deb
        echo "✅ Cloudflared installed"
    else
        echo "✅ Cloudflared already installed"
    fi
}

# Setup Cloudflare tunnel
setup_tunnel() {
    echo ""
    echo "Setting up Cloudflare tunnel..."
    echo "Domain: ${CF_DOMAIN}"
    echo ""

    # Login to Cloudflare
    echo "Step 1: Logging into Cloudflare..."
    cloudflared tunnel login

    # Create tunnel
    echo ""
    echo "Step 2: Creating tunnel..."
    cloudflared tunnel create ${CF_TUNNEL_NAME}

    # Get tunnel ID
    TUNNEL_ID=$(cloudflared tunnel list | grep ${CF_TUNNEL_NAME} | awk '{print $1}')
    echo "Tunnel ID: $TUNNEL_ID"

    # Create config file
    echo ""
    echo "Step 3: Creating tunnel configuration..."
    mkdir -p ~/.cloudflared
    cat > ~/.cloudflared/config.yml << EOF
tunnel: $TUNNEL_ID
credentials-file: /home/$USER/.cloudflared/$TUNNEL_ID.json

ingress:
  - hostname: ${CF_DOMAIN}
    service: http://localhost:${ABS_PORT}
    originRequest:
      noTLSVerify: true
      connectTimeout: 30s

  - service: http_status:404
EOF

    echo "✅ Configuration created"

    # Create DNS record
    echo ""
    echo "Step 4: Creating DNS record for ${CF_DOMAIN}..."
    cloudflared tunnel route dns ${CF_TUNNEL_NAME} ${CF_DOMAIN}
    echo "✅ DNS record created"

    # Create systemd service (needs config in /etc/cloudflared on modern cloudflared)
    echo ""
    echo "Step 5: Installing as system service..."
    sudo mkdir -p /etc/cloudflared
    sudo cp "$HOME/.cloudflared/config.yml" /etc/cloudflared/config.yml
    sudo cp "$HOME/.cloudflared/${TUNNEL_ID}.json" /etc/cloudflared/
    sudo sed -i "s|$HOME/.cloudflared/|/etc/cloudflared/|" /etc/cloudflared/config.yml
    sudo cloudflared service install
    echo "✅ Service installed"

    # Start tunnel
    echo ""
    echo "Step 6: Starting tunnel..."
    sudo systemctl start cloudflared
    sudo systemctl enable cloudflared
    echo "✅ Tunnel started"
}

# Test connection
test_connection() {
    echo ""
    echo "Testing connection to ${CF_DOMAIN}..."
    sleep 5

    if curl -sf https://${CF_DOMAIN} > /dev/null 2>&1; then
        echo "✅ Tunnel is working!"
        echo ""
        echo "Your Audiobookshelf is now accessible at:"
        echo "  https://${CF_DOMAIN}"
    else
        echo "⚠️  Tunnel may still be starting. Wait a moment and try:"
        echo "  https://${CF_DOMAIN}"
    fi
}

# Main
main() {
    echo "This will set up Cloudflare tunnel for public access."
    echo ""
    echo "Prerequisites:"
    echo "• Cloudflare account (free)"
    echo "• Domain added to Cloudflare"
    echo "• Audiobookshelf running locally"
    echo ""

    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi

    install_cloudflared
    setup_tunnel
    test_connection

    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║              Setup Complete!                      ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""
    echo "Share this URL: https://${CF_DOMAIN}"
    echo ""
    echo "Remember to:"
    echo "1. Create guest accounts in Audiobookshelf"
    echo "2. Set appropriate permissions"
    echo "3. Monitor access logs"
}

main "$@"