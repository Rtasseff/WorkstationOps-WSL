#!/usr/bin/env bash
# backups/wsl-backup.sh — rsync backup of WSL home to network drive
#
# Usage:
#   ./backups/wsl-backup.sh              # quiet mode (for cron)
#   ./backups/wsl-backup.sh --verbose    # interactive with progress
#   ./backups/wsl-backup.sh --dry-run    # test without writing
#   ./backups/wsl-backup.sh --verbose --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$OPS_ROOT/lib/common.sh"
source "$OPS_ROOT/config/backup.conf"

# --- Parse flags ---
VERBOSE=false
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --verbose) VERBOSE=true ;;
        --dry-run) DRY_RUN=true ;;
        *) log_error "Unknown flag: $arg"; exit 1 ;;
    esac
done

LOCK_NAME="workstationops-backup"
LOG_DIR="$OPS_ROOT/logs"
LOG_FILE="$LOG_DIR/backup-$(date '+%Y-%m-%d').log"

# --- Cleanup on exit ---
cleanup() {
    release_lock "$LOCK_NAME"
}
trap cleanup EXIT

# --- Redirect output to log file (append) ---
ensure_dir "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

# --- Mount safety check ---
if [[ ! -d "$BACKUP_MOUNT_CHECK" ]]; then
    log_warn "Network drive not mounted — $BACKUP_MOUNT_CHECK does not exist. Skipping backup."
    exit 0
fi

# Check that the mount point is non-empty (at least one entry besides . and ..)
if [[ -z "$(ls -A "$BACKUP_MOUNT_CHECK" 2>/dev/null)" ]]; then
    log_warn "Network drive appears empty — $BACKUP_MOUNT_CHECK has no contents. Skipping backup."
    exit 0
fi

# --- Lock ---
if ! acquire_lock "$LOCK_NAME"; then
    exit 1
fi

# --- Validate source ---
if [[ ! -d "$BACKUP_SOURCE" ]]; then
    log_error "Backup source does not exist: $BACKUP_SOURCE"
    exit 1
fi

# --- Rotate old logs ---
rotate_logs "$LOG_DIR" "$LOG_RETENTION_DAYS"

# --- Build rsync command ---
EXCLUDE_FILE="$OPS_ROOT/backups/wsl-backup.exclude"

rsync_args=(
    -a
    --delete
    --exclude-from="$EXCLUDE_FILE"
    --log-file="$LOG_FILE"
    --stats
)

if $VERBOSE; then
    rsync_args+=(-vh --info=progress2)
fi

if $DRY_RUN; then
    rsync_args+=(--dry-run)
    log_info "DRY RUN — no files will be modified"
fi

# Ensure dest exists
ensure_dir "$BACKUP_DEST"

# --- Run backup ---
log_info "Backup starting: $BACKUP_SOURCE -> $BACKUP_DEST"
start_time=$(date +%s)

rsync_exit=0
rsync "${rsync_args[@]}" "$BACKUP_SOURCE/" "$BACKUP_DEST/" || rsync_exit=$?

end_time=$(date +%s)
duration=$(( end_time - start_time ))

if [[ $rsync_exit -eq 0 ]]; then
    log_success "Backup completed in $(human_duration $duration)"
elif [[ $rsync_exit -eq 24 ]]; then
    # Exit 24 = some files vanished during transfer (normal for a live system)
    log_warn "Backup completed with warnings (some files vanished) in $(human_duration $duration)"
else
    log_error "Backup failed with exit code $rsync_exit after $(human_duration $duration)"
    exit $rsync_exit
fi
