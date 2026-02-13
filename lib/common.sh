#!/usr/bin/env bash
# lib/common.sh — Shared utilities for WorkstationOps
# Source this file; do not execute directly.

set -euo pipefail

# --- Colors (disabled when not a TTY, e.g. cron) ---
if [[ -t 1 ]]; then
    _RED=$'\033[0;31m'
    _GREEN=$'\033[0;32m'
    _YELLOW=$'\033[0;33m'
    _BLUE=$'\033[0;34m'
    _BOLD=$'\033[1m'
    _RESET=$'\033[0m'
else
    _RED="" _GREEN="" _YELLOW="" _BLUE="" _BOLD="" _RESET=""
fi

# --- Logging ---

_log() {
    local level="$1" color="$2" msg="$3"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '%s [%b%-5s%b] %s\n' "$ts" "$color" "$level" "$_RESET" "$msg"
}

log_info()    { _log "INFO"  "$_BLUE"   "$*"; }
log_warn()    { _log "WARN"  "$_YELLOW" "$*"; }
log_error()   { _log "ERROR" "$_RED"    "$*"; }
log_success() { _log "OK"    "$_GREEN"  "$*"; }

# --- Lock files ---

acquire_lock() {
    local name="${1:?lock name required}"
    local lockfile="/tmp/${name}.lock"

    if [[ -f "$lockfile" ]]; then
        local old_pid
        old_pid=$(<"$lockfile")
        if kill -0 "$old_pid" 2>/dev/null; then
            log_error "Another instance is running (PID $old_pid). Exiting."
            return 1
        else
            log_warn "Removing stale lock file (PID $old_pid no longer running)."
            rm -f "$lockfile"
        fi
    fi

    echo $$ > "$lockfile"
}

release_lock() {
    local name="${1:?lock name required}"
    local lockfile="/tmp/${name}.lock"
    rm -f "$lockfile"
}

# --- Log rotation ---

rotate_logs() {
    local log_dir="${1:?log directory required}"
    local retention_days="${2:-30}"

    if [[ -d "$log_dir" ]]; then
        find "$log_dir" -name '*.log' -type f -mtime +"$retention_days" -delete
    fi
}

# --- Utilities ---

ensure_dir() {
    local dir="${1:?directory path required}"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
    fi
}

human_duration() {
    local seconds="${1:?seconds required}"
    local h m s
    h=$(( seconds / 3600 ))
    m=$(( (seconds % 3600) / 60 ))
    s=$(( seconds % 60 ))

    local parts=()
    (( h > 0 )) && parts+=("${h}h")
    (( m > 0 )) && parts+=("${m}m")
    parts+=("${s}s")

    echo "${parts[*]}"
}
