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

### drvfs Limitations

The network drive uses Windows drvfs, which does not support Unix symlinks, file permissions, ownership, or reliable timestamp setting. The backup script handles this with:

- **`--no-links`** — symlinks are skipped (drvfs cannot create them)
- **`--no-times`** — timestamps are not preserved (drvfs rejects `utimes()` on many files)
- **`--size-only`** — change detection uses file size instead of mod-time

**What this means:** Backup file timestamps reflect *when the backup ran*, not the original modification time. File content is fully preserved. The tradeoff is that files modified without a size change (rare) won't be re-transferred until their size differs. Git history, file content, and directory structure are all intact.

## Restore Procedures

### Full Restore

Restoring *to* a Linux filesystem supports full `-a` mode (no drvfs restrictions):

```bash
rsync -avh /mnt/k/rtasseff/wsl/ /home/rtasseff/
```

Note: File timestamps will reflect backup time, not original modification time (see [drvfs Limitations](#drvfs-limitations)).

### Selective Restore (single directory)

```bash
rsync -avh /mnt/k/rtasseff/wsl/projects/ /home/rtasseff/projects/
```

### Single File

```bash
cp /mnt/k/rtasseff/wsl/path/to/file /home/rtasseff/path/to/file
```

## Shell Integration

A block in `~/.bashrc` shows a one-line backup status summary once per day when you open a WSL session:

```
WorkstationOps: Backup ran 3h ago | Next: Tue 12:00 PM
```

To install, add the following to the end of your `~/.bashrc`:

```bash
# BEGIN WorkstationOps
# Daily status reminder — shows backup status once per day
# Gate: only run when stdout is a real terminal (skips tool-spawned shells like Claude Code)
if [[ -t 1 ]] && [[ -x "$HOME/WorkstationOps/ops" ]]; then
    _wso_check_file="$HOME/.cache/workstationops_last_check"
    _wso_today=$(date +%Y-%m-%d)
    _wso_last=""
    [[ -f "$_wso_check_file" ]] && _wso_last=$(<"$_wso_check_file")
    if [[ "$_wso_today" != "$_wso_last" ]]; then
        if "$HOME/WorkstationOps/ops" status --brief 2>/dev/null; then
            mkdir -p "$HOME/.cache"
            echo "$_wso_today" > "$_wso_check_file"
        fi
    fi
    unset _wso_check_file _wso_today _wso_last
fi
# END WorkstationOps
```

The gate file `~/.cache/workstationops_last_check` stores the date of the last successful status display. If `ops status --brief` fails (e.g., during early boot before services are ready), the gate is not updated, so the next session will retry.

## Configuration

Edit `config/backup.conf` to change:
- Source/destination paths
- Cron schedule (default: `0 12 * * *` — daily at noon)
- Log retention period (default: 30 days)

## Notes

- **`.ssh/` and `.gnupg/` are excluded** from backups for security. Back up keys manually to a secure location.
- **`.claude/` is excluded** — regenerable tool state (plugins, cache, debug logs). Claude Code recreates it automatically.
- **Symlinks are not backed up** — drvfs cannot create them. Symlinks in the home directory are typically tool-generated (e.g., `.claude/debug/latest`) and regenerable.
- **Network drive required:** The K: drive must be mounted via fstab (`K: /mnt/k drvfs defaults 0 0`). See `setup/install-notes.md`.
- **systemd required:** Cron persistence depends on `systemd=true` in `/etc/wsl.conf`.
