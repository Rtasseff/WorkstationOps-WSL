# CLAUDE.md — WorkstationOps (biomaGUNE WSL)

## Scope & Identity

This project is the **biomaGUNE WSL** instance of WorkstationOps. The user maintains other WorkstationOps projects on different machines (biomaGUNE Windows, home macbook) — same name, different hosts, different operations. Assumptions from other instances do not transfer here.

## Purpose

WorkstationOps is a **general operations container** for this workstation, not a single-purpose tool. It exists to hold any recurring or on-demand op needed to keep this machine healthy. The `./ops` CLI is a dispatcher — new operations should be added as subcommands rather than as standalone scripts.

Currently the only implemented operation is the WSL home backup. When adding a second operation, reframe anything in the docs or CLI that still reads as backup-only.

## Layout

- `ops` — CLI dispatcher. Main subcommand switch lives near the bottom (`case "$cmd" in ...`).
- `lib/common.sh` — shared logging, locks, color helpers. Reuse from here; don't duplicate.
- `lib/cron-manager.sh` — marker-based crontab add/remove/list. Reuse for any cron-scheduled op.
- `config/` — per-operation config files (e.g. `backup.conf`). New ops should add their own config file here rather than overloading existing ones.
- `backups/` — the backup operation's implementation (script + rsync exclude list).
- `logs/` — runtime logs. Log rotation is handled in the backup script; new ops should follow the same pattern.
- `setup/` — one-time setup notes (fstab entry, wsl.conf, etc.).

## Adding a New Operation

1. Create its implementation directory (e.g. `maintenance/`).
2. Add a config file in `config/` if it has tunables.
3. Add a `cmd_<name>()` function and wire it into the `case` block in `ops`.
4. If it needs scheduling, use `lib/cron-manager.sh` with a unique marker.
5. Update the "Current Operations" table in `README.md`.

## drvfs Gotcha (Do Not Undo)

The backup target is on Windows drvfs via `/mnt/k`. drvfs does **not** support symlinks, Unix permissions, ownership, or reliable `utimes()` on files or directories. The backup script intentionally uses `rsync -rD --no-links --no-times --size-only` — not `-a`.

If you see rsync flags that look "incomplete," do not restore `-a`. It will fail hard on `.git/objects` temp files and other common cases. This was discovered by incident; the current flags are deliberate.

Any new op that writes to `/mnt/k` must respect the same constraints.

## Environment Constraints

- WSL2 with `systemd=true` (cron persistence depends on it).
- K: drive mounted via fstab at `/mnt/k` (drvfs). Ops touching the network drive must check mount state before writing — see `_is_mounted` in `ops` for the pattern.
- bash, rsync 3.2.7.

## Conventions

- One CLI entry point (`./ops`). Do not introduce competing top-level scripts.
- Idempotent scheduling (re-running `schedule` should not duplicate cron entries).
- Safe-by-default: when an external dependency (mount, network) is missing, exit cleanly rather than partially executing.
- Lock files to prevent overlapping runs of the same op.
