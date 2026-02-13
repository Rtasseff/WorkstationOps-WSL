#!/usr/bin/env bash
# lib/cron-manager.sh — Marker-based cron job management
# Source this file; do not execute directly.

# Marker prefix used to identify managed cron entries
_CRON_MARKER="WorkstationOps"

_begin_marker() { echo "# BEGIN ${_CRON_MARKER}:${1}"; }
_end_marker()   { echo "# END ${_CRON_MARKER}:${1}"; }

install_cron_job() {
    local job_name="${1:?job name required}"
    local schedule="${2:?schedule required}"
    local command="${3:?command required}"

    local begin end
    begin="$(_begin_marker "$job_name")"
    end="$(_end_marker "$job_name")"

    local new_block
    new_block=$(printf '%s\n%s %s 2>&1\n%s' "$begin" "$schedule" "$command" "$end")

    local current_cron
    current_cron=$(crontab -l 2>/dev/null || true)

    if echo "$current_cron" | grep -qF "$begin"; then
        # Replace existing block
        local updated
        updated=$(echo "$current_cron" | awk -v begin="$begin" -v end="$end" -v block="$new_block" '
            $0 == begin { skip=1; printed=0; next }
            $0 == end   { skip=0; if (!printed) { print block; printed=1 }; next }
            skip { next }
            { print }
        ')
        echo "$updated" | crontab -
    else
        # Append new block
        if [[ -n "$current_cron" ]]; then
            printf '%s\n%s\n' "$current_cron" "$new_block" | crontab -
        else
            echo "$new_block" | crontab -
        fi
    fi
}

remove_cron_job() {
    local job_name="${1:?job name required}"

    local begin end
    begin="$(_begin_marker "$job_name")"
    end="$(_end_marker "$job_name")"

    local current_cron
    current_cron=$(crontab -l 2>/dev/null || true)

    if ! echo "$current_cron" | grep -qF "$begin"; then
        return 0  # nothing to remove
    fi

    local updated
    updated=$(echo "$current_cron" | awk -v begin="$begin" -v end="$end" '
        $0 == begin { skip=1; next }
        $0 == end   { skip=0; next }
        skip { next }
        { print }
    ')

    # Remove trailing blank lines
    updated=$(echo "$updated" | sed -e :a -e '/^\n*$/{$d;N;ba}')

    if [[ -z "$updated" ]]; then
        crontab -r 2>/dev/null || true
    else
        echo "$updated" | crontab -
    fi
}

list_cron_jobs() {
    local current_cron
    current_cron=$(crontab -l 2>/dev/null || true)

    if [[ -z "$current_cron" ]]; then
        echo "No cron jobs installed."
        return
    fi

    local found=false
    echo "$current_cron" | while IFS= read -r line; do
        if [[ "$line" == "# BEGIN ${_CRON_MARKER}:"* ]]; then
            local name="${line#"# BEGIN ${_CRON_MARKER}:"}"
            found=true
            # Next line is the cron entry
            IFS= read -r cron_line
            echo "  $name: $cron_line"
        fi
    done

    if ! echo "$current_cron" | grep -q "# BEGIN ${_CRON_MARKER}:"; then
        echo "No WorkstationOps cron jobs found."
    fi
}

is_job_scheduled() {
    local job_name="${1:?job name required}"
    local begin
    begin="$(_begin_marker "$job_name")"
    crontab -l 2>/dev/null | grep -qF "$begin"
}
