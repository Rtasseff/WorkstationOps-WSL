# WorkstationOps

Automated daily backup of the WSL home directory (`/home/rtasseff`) to a network drive (`/mnt/k/rtasseff/wsl/`).

Backups run via cron at noon daily. The script detects when the network drive is unavailable and skips safely — no risk of `--delete` wiping backups when disconnected.

## Quick Start

```bash
./ops verify        # check environment
./ops schedule      # install cron job
./ops status        # confirm everything looks good
```

## Commands

| Command | Description |
|---|---|
| `./ops status` | Show backup status, schedule, mount state |
| `./ops status --brief` | Single-line status (used in .bashrc) |
| `./ops schedule` | Install daily backup cron job (idempotent) |
| `./ops unschedule` | Remove backup cron job |
| `./ops run backup` | Run backup interactively with progress |
| `./ops run backup --dry-run` | Test run without writing files |
| `./ops logs [N]` | Show last N lines of latest log (default: 50) |
| `./ops verify` | Pre-flight checks (rsync, paths, cron, disk) |
| `./ops help` | Show usage info |

## How It Works

- **rsync** with `--delete` keeps the backup in sync, transferring only changes
- **Exclusion list** (`backups/wsl-backup.exclude`) skips caches, build artifacts, and sensitive files (~10GB saved)
- **Mount safety:** Before every run, the script checks that `/mnt/k/rtasseff` exists and is non-empty. If the network drive isn't connected, the backup exits cleanly
- **Lock file** prevents overlapping runs
- **Log rotation** cleans up logs older than 30 days

## Restore Procedures

### Full Restore

```bash
rsync -avh /mnt/k/rtasseff/wsl/ /home/rtasseff/
```

### Selective Restore (single directory)

```bash
rsync -avh /mnt/k/rtasseff/wsl/projects/ /home/rtasseff/projects/
```

### Single File

```bash
cp /mnt/k/rtasseff/wsl/path/to/file /home/rtasseff/path/to/file
```

## Configuration

Edit `config/backup.conf` to change:
- Source/destination paths
- Cron schedule (default: `0 12 * * *` — daily at noon)
- Log retention period (default: 30 days)

## Notes

- **`.ssh/` and `.gnupg/` are excluded** from backups for security. Back up keys manually to a secure location.
- **Network drive required:** The K: drive must be mounted via fstab (`K: /mnt/k drvfs defaults 0 0`). See `setup/install-notes.md`.
- **systemd required:** Cron persistence depends on `systemd=true` in `/etc/wsl.conf`.
