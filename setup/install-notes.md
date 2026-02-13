# Install Notes

## WSL2 Environment

- **Distro:** Ubuntu on WSL2
- **systemd:** Enabled (`systemd=true` in `/etc/wsl.conf`), so cron persists across terminal closures
- **Shell:** bash

## Network Drive (K:)

The Windows `K:` drive is mounted via fstab:

```
# /etc/fstab
K: /mnt/k drvfs defaults 0 0
```

This makes `/mnt/k` available inside WSL when the network drive is connected on the Windows side.

**Important:** If the machine starts without network access (e.g., working from home without VPN), `/mnt/k` will exist but be empty. The backup script detects this and skips the run safely.

## Dependencies

- **rsync** (3.2.7+): `sudo apt install rsync`
- **cron**: Included with Ubuntu, started by systemd automatically

## Manual Key Backup

`.ssh/` and `.gnupg/` are excluded from automated backups for security. Back up SSH keys and GPG keys manually to a secure location if needed.
