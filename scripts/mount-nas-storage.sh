#!/bin/bash

# NAS Storage Mount Script for Audiobookshelf
# Mounts network storage via SMB/CIFS

set -e

echo "╔══════════════════════════════════════════════════╗"
echo "║      NAS Storage Mount for Audiobookshelf        ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Error: .env file not found. Please configure your NAS settings."
    exit 1
fi

# Default values if not in .env
NAS_IP=${NAS_IP:-"192.168.0.1"}
NAS_SHARE_PATH=${NAS_SHARE_PATH:-"/media/Audiobooks"}
NAS_MOUNT_POINT=${NAS_MOUNT_POINT:-"/mnt/nas-audiobooks"}
NAS_USERNAME=${NAS_USERNAME:-""}

# Check requirements
check_requirements() {
    echo "Checking requirements..."

    if ! command -v mount.cifs &> /dev/null; then
        echo "Installing CIFS utilities..."
        sudo apt-get update && sudo apt-get install -y cifs-utils
    fi
    echo "✅ CIFS utilities installed"
}

# Create credentials file
create_credentials() {
    CRED_FILE="config/nas-credentials"

    if [ ! -f "$CRED_FILE" ]; then
        echo ""
        echo "Creating NAS credentials file..."
        mkdir -p config

        read -p "NAS Username [$NAS_USERNAME]: " username
        username=${username:-$NAS_USERNAME}

        read -s -p "NAS Password: " password
        echo

        read -p "NAS Domain (optional, press Enter to skip): " domain

        cat > "$CRED_FILE" << EOF
username=$username
password=$password
${domain:+domain=$domain}
EOF
        chmod 600 "$CRED_FILE"
        echo "✅ Credentials file created"
    else
        echo "✅ Using existing credentials file"
    fi
}

# Mount NAS
mount_nas() {
    echo ""
    echo "Mounting NAS storage..."
    echo "  NAS: //$NAS_IP$NAS_SHARE_PATH"
    echo "  Mount point: $NAS_MOUNT_POINT"

    # Check if already mounted
    if mount | grep -q "$NAS_MOUNT_POINT"; then
        echo "✅ NAS already mounted"
        return 0
    fi

    # Create mount point
    sudo mkdir -p "$NAS_MOUNT_POINT"

    # Mount the share
    sudo mount -t cifs "//$NAS_IP$NAS_SHARE_PATH" "$NAS_MOUNT_POINT" \
        -o credentials="$(pwd)/config/nas-credentials",uid=1000,gid=1000,iocharset=utf8,file_mode=0755,dir_mode=0755

    if mount | grep -q "$NAS_MOUNT_POINT"; then
        echo "✅ NAS mounted successfully"

        # Test access
        if ls "$NAS_MOUNT_POINT" > /dev/null 2>&1; then
            echo "✅ Mount is accessible"
            echo ""
            echo "Contents preview:"
            ls -la "$NAS_MOUNT_POINT" | head -5
        fi
    else
        echo "❌ Failed to mount NAS"
        exit 1
    fi
}

# Add to fstab for persistence
setup_persistent_mount() {
    echo ""
    read -p "Add to /etc/fstab for automatic mounting? (y/n): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        FSTAB_ENTRY="//$NAS_IP$NAS_SHARE_PATH $NAS_MOUNT_POINT cifs credentials=$(pwd)/config/nas-credentials,uid=1000,gid=1000,iocharset=utf8,file_mode=0755,dir_mode=0755,vers=3.0,_netdev,nofail,ro 0 0"

        if ! grep -q "$NAS_IP$NAS_SHARE_PATH" /etc/fstab; then
            echo ""
            echo "Add this line to /etc/fstab:"
            echo "$FSTAB_ENTRY"
            echo ""
            echo "Run: echo '$FSTAB_ENTRY' | sudo tee -a /etc/fstab"
        else
            echo "✅ Already in /etc/fstab"
        fi
    fi
}

# Update docker-compose
update_docker_compose() {
    echo ""
    echo "To use NAS storage in Audiobookshelf:"
    echo ""
    echo "1. Edit docker/docker-compose.yml"
    echo "2. Add this volume mount:"
    echo "   - $NAS_MOUNT_POINT:/nas-audiobooks:ro"
    echo ""
    echo "3. Restart Audiobookshelf:"
    echo "   docker compose -f docker/docker-compose.yml restart"
    echo ""
    echo "   Note: after the first 'mount -a', run 'docker restart audiobookshelf'"
    echo "   once so the running container picks up the new mount."
    echo "   Future reboots don't need this — fstab runs before Docker."
    echo ""
    echo "4. In Audiobookshelf web UI:"
    echo "   - Go to Settings → Libraries"
    echo "   - Add folder: /nas-audiobooks"
}

# Main
main() {
    echo "This will mount your NAS storage for Audiobookshelf."
    echo ""
    echo "Current configuration:"
    echo "  NAS IP: $NAS_IP"
    echo "  Share Path: $NAS_SHARE_PATH"
    echo "  Mount Point: $NAS_MOUNT_POINT"
    echo ""

    read -p "Continue with NAS mount? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi

    check_requirements
    create_credentials
    mount_nas
    setup_persistent_mount
    update_docker_compose

    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║           NAS Mount Complete!                    ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""
    echo "Your NAS is mounted at: $NAS_MOUNT_POINT"
    echo ""
    echo "Commands:"
    echo "  umount $NAS_MOUNT_POINT  - Unmount"
    echo "  mount -a                  - Remount all"
}

main "$@"