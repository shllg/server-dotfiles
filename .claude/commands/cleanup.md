---
description: Reclaim disk space across all subsystems
---

Audit disk usage across the system and identify reclaimable space. **Do not delete anything without asking first.**

## Checks (run in this order)

1. **Overview**: `df -h` — flag any filesystem above 80%
2. **Big consumers**: `du -sh /var/log /var/cache /tmp /var/tmp /root /home /opt --total 2>/dev/null`
3. **Journal logs**: `journalctl --disk-usage` — offer to vacuum if above 500M (`journalctl --vacuum-size=500M`)
4. **APT cache**: `du -sh /var/cache/apt/archives` — offer `apt-get clean` and `apt-get autoremove --simulate`
5. **Old rotated logs**: find `*.gz`, `*.1`, `*.old` files in `/var/log` older than 30 days
6. **Git worktrees**: for each git repo under `/root`, run `git worktree list --porcelain` and flag stale/orphaned worktrees. Also check for leftover directories that are no longer linked.
7. **Docker** (if present): `docker system df` — offer `docker system prune`
8. **Temp files**: find files in `/tmp` and `/var/tmp` older than 7 days
9. **Old kernels**: list `linux-image-*` packages not matching the running kernel (`uname -r`)
10. **Dangling symlinks**: `find /root -maxdepth 3 -type l ! -exec test -e {} \; -print 2>/dev/null`

## Output

Present a summary table:

| Category | Current size | Reclaimable | Action |
|----------|-------------|-------------|--------|

Then ask the user which categories to clean up. Execute only what they approve.
