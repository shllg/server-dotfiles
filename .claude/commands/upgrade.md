---
description: Safe system upgrade with pre/post verification
---

Perform a system package upgrade with safety checks before and after. Follow this procedure exactly.

## 1. Pre-flight baseline

Capture current state — save these results to compare later:

- `tailscale status` — connection state
- `ss -tlnp` — listening ports snapshot
- `systemctl --failed` — currently failed units
- `systemctl list-units --type=service --state=running --no-pager` — running services

## 2. Simulate

```
apt-get update && apt-get --simulate upgrade
```

Show the user what would change. Flag these risks explicitly:
- **Kernel upgrades** → will require a reboot
- **openssh-server** → could affect SSH access
- **systemd** → could affect all services
- **nftables/iptables** → could affect firewall
- **tailscale** → could affect connectivity (critical!)

If any of these are in the upgrade list, call them out prominently.

## 3. Confirm

**Stop and ask the user** whether to proceed. If risky packages are involved, recommend upgrading them separately with extra verification between each.

## 4. Execute

Run `apt-get upgrade -y` (or `apt-get full-upgrade -y` only if the user explicitly requests it).

## 5. Post-flight verification

Re-run the pre-flight checks and **diff against the baseline**:
- Are the same ports still listening?
- Are the same services still running?
- Are there new failed units?
- Is Tailscale still connected?

Report any differences. If a service that was running is now stopped or failed, investigate immediately with `journalctl -u <unit> -n 50`.

## 6. Reboot advisory

If a kernel was upgraded, tell the user. Do **not** reboot without explicit permission.
