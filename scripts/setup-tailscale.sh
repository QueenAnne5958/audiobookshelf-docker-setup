#!/bin/bash

# Tailscale VPN Setup for Audiobookshelf
# Provides secure remote access without port forwarding

set -e

echo "╔══════════════════════════════════════════════════╗"
echo "║     Tailscale VPN Setup for Audiobookshelf       ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Warning: .env file not found"
fi

# Check if Tailscale is installed
install_tailscale() {
    if command -v tailscale &> /dev/null; then
        echo "✅ Tailscale is already installed"
        return 0
    fi

    echo "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    echo "✅ Tailscale installed successfully"
}

# Setup Tailscale
setup_tailscale() {
    echo ""
    echo "Starting Tailscale..."
    sudo tailscale up

    echo ""
    echo "Waiting for Tailscale to connect..."
    sleep 3

    # Get Tailscale IP
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "Not yet assigned")

    if [ "$TAILSCALE_IP" != "Not yet assigned" ]; then
        echo ""
        echo "✅ Tailscale is connected!"
        echo ""
        echo "╔══════════════════════════════════════════════════╗"
        echo "║           Tailscale Setup Complete!              ║"
        echo "╚══════════════════════════════════════════════════╝"
        echo ""
        echo "Your Tailscale IP: $TAILSCALE_IP"
        echo ""
        echo "Access Audiobookshelf from any device with Tailscale:"
        echo "  http://$TAILSCALE_IP:${ABS_PORT:-13378}"
        echo ""
        echo "To connect other devices:"
        echo "1. Install Tailscale on the device"
        echo "2. Login with the same account"
        echo "3. Use the URL above"
    else
        echo "⚠️  Tailscale is starting. Run 'tailscale status' to check."
    fi
}

# Configure firewall (optional)
configure_firewall() {
    echo ""
    read -p "Configure firewall for Tailscale? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Allowing Tailscale traffic..."
        sudo ufw allow in on tailscale0
        sudo ufw allow 41641/udp
        echo "✅ Firewall configured"
    fi
}

# Main
main() {
    echo "This will set up Tailscale VPN for secure remote access."
    echo "No port forwarding required!"
    echo ""
    echo "Benefits:"
    echo "• End-to-end encryption"
    echo "• No exposed ports"
    echo "• Works behind any NAT"
    echo "• Free for personal use"
    echo ""

    read -p "Continue with Tailscale setup? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi

    install_tailscale
    setup_tailscale
    configure_firewall

    echo ""
    echo "Additional commands:"
    echo "  tailscale status     - Check connection status"
    echo "  tailscale netcheck   - Test connectivity"
    echo "  tailscale logout     - Disconnect from network"
}

main "$@"