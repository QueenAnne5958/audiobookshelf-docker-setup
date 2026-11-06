# Audiobookshelf Docker Setup

Automated Docker setup for [Audiobookshelf](https://www.audiobookshelf.org/) with remote access capabilities via Cloudflare Tunnel or Tailscale.

## Features

- 🐳 Docker Compose based deployment
- 🌐 Cloudflare Tunnel for secure remote access (no port forwarding)
- 📚 NAS/Network storage support
- 🔧 Automated setup scripts
- 🔒 Security best practices
- 📱 Mobile app ready

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Linux server (Ubuntu/Debian recommended)
- (Optional) Cloudflare account for remote access
- (Optional) NAS for network storage

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/dleerdefi/audiobookshelf-docker-setup.git
cd audiobookshelf-docker-setup
```

2. **Configure environment**
```bash
cp .env.template .env
nano .env  # Edit with your values
```

3. **Run setup**
```bash
chmod +x scripts/*.sh
./scripts/setup-audiobookshelf.sh
```

4. **Access Audiobookshelf**
- Local: `http://localhost:13378`
- Network: `http://YOUR_IP:13378`

## Remote Access Setup

### Option 1: Cloudflare Tunnel (Recommended)

Perfect for sharing with friends/family without exposing your home network.

```bash
./scripts/setup-cloudflare-tunnel.sh
```

This will:
- Install cloudflared
- Create a secure tunnel
- Configure your domain (e.g., `abs.yourdomain.com`)
- No port forwarding required!

### Option 2: Tailscale VPN

For personal use only - most secure option.

```bash
./scripts/setup-tailscale.sh
```

## Boot Resilience

After a reboot (planned or power outage), these come back automatically if set up correctly:

| Component | Auto-starts? | What makes it so |
|-----------|--------------|------------------|
| Docker daemon | Yes | `systemctl enable docker` (default on Ubuntu) |
| Audiobookshelf container | Yes | `restart: unless-stopped` in compose |
| Cloudflare tunnel | Yes, **if** installed as service | `cloudflared service install` + `systemctl enable cloudflared` — both done by `setup-cloudflare-tunnel.sh` |
| NAS audiobooks mount | Yes, **if** in `/etc/fstab` | Entry with `_netdev,nofail,ro` — added via `mount-nas-storage.sh` |

Post-reboot sanity check:

```bash
systemctl is-enabled cloudflared docker   # both "enabled"
mount | grep nas-audiobooks                # CIFS mount present
docker ps | grep audiobookshelf            # "(healthy)"
curl -I https://YOUR_CF_DOMAIN             # HTTP 200
```

**One-time gotcha:** the very first time you add the NAS entry to fstab on a running system, run `docker restart audiobookshelf` once so the container sees the new mount. Subsequent reboots don't need this because fstab runs before Docker.

## NAS/Network Storage

To mount network storage:

1. **Configure NAS settings in .env**
```bash
# Edit your .env file with NAS details
NAS_IP=192.168.x.x
NAS_SHARE_PATH=/media/Audiobooks
```

2. **Mount NAS**
```bash
./scripts/mount-nas-storage.sh
```

3. **Update docker-compose.yml**
Uncomment the NAS volume mount line.

## Mobile App Setup

1. Download Audiobookshelf app (iOS/Android)
2. Add server:
   - Local: `http://192.168.x.x:13378`
   - Remote: `https://abs.yourdomain.com`
3. Login with your credentials

## Troubleshooting

### Container won't start
```bash
docker logs audiobookshelf
```

### Can't access remotely
```bash
# Is the tunnel set up to auto-start? (`enabled` means yes)
systemctl is-enabled cloudflared
sudo systemctl status cloudflared

# Test connectivity
curl -I https://abs.yourdomain.com
```

If `is-enabled` returns `not-found` or `disabled`, the tunnel won't come back on reboot — re-run `./scripts/setup-cloudflare-tunnel.sh` or `sudo cloudflared service install` + `sudo systemctl enable --now cloudflared`.

### NAS mount issues
```bash
# Check mount
mount | grep nas-audiobooks

# Remount
./scripts/mount-nas-storage.sh
```

## License

MIT License