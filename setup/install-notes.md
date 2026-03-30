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

## drvfs Filesystem Limitations

The drvfs filesystem (used by WSL to mount Windows drives) does **not** support:

- **Unix symlinks** — `symlink()` returns "Operation not permitted"
- **Unix permissions/ownership** — `chmod`, `chown`, `chgrp` silently fail or error
- **Reliable timestamp setting** — `utimes()` fails on many files, especially git objects and temp files

This means rsync's standard `-a` (archive) flag cannot be used. The backup script uses `-rD --no-links --no-times --size-only` instead. See the comments in `backups/wsl-backup.sh` for details.

**Consequence:** Backed-up files have the timestamp of when the backup ran, not the original modification time. Change detection between runs uses file size comparison (`--size-only`), which is fast but won't catch modifications that don't change file size. For a daily backup this is an acceptable tradeoff.

## Dependencies

- **rsync** (3.2.7+): `sudo apt install rsync`
- **cron**: Included with Ubuntu, started by systemd automatically

## Shell Integration

Add the WorkstationOps block to `~/.bashrc` to see daily backup status on shell open. See the [Shell Integration](../README.md#shell-integration) section in the README for the snippet and details.

## Manual Key Backup

`.ssh/` and `.gnupg/` are excluded from automated backups for security. Back up SSH keys and GPG keys manually to a secure location if needed.
