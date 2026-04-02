---
description: Security and stability audit
---

Run a security and stability audit of this server. Check each area and report findings as OK / WARN / CRITICAL.

## Security Checks
1. **Listening ports**: `ss -tlnp` — flag anything bound to 0.0.0.0 or public IP that isn't Tailscale-related
2. **Firewall**: dump current iptables/nftables rules — verify only Tailscale and loopback traffic is allowed inbound
3. **SSH config**: check `/etc/ssh/sshd_config` for PasswordAuthentication, PermitRootLogin, and allowed auth methods
4. **Tailscale**: `tailscale status` — confirm connected and ACLs look right
5. **Open users**: check `/etc/passwd` for unexpected shells, `/etc/shadow` for accounts with passwords
6. **Unattended upgrades**: verify automatic security updates are enabled
7. **File permissions**: check that sensitive files (secrets, keys, tokens) are 0600 and owned by root
8. **Running services**: `systemctl list-units --type=service --state=running` — flag unexpected services

## Stability Checks
1. **Disk usage**: `df -h` — warn if any mount is above 80%
2. **Memory**: `free -h` — report current usage
3. **Systemd failed units**: `systemctl --failed`
4. **Journal errors**: `journalctl -p err --since "24 hours ago" --no-pager | tail -50`
5. **DNS resolution**: `resolvectl status` and test with `dig github.com`
6. **NTP sync**: `timedatectl status`
7. **Zombie/stuck processes**: `ps aux | awk '$8 ~ /Z/'`
8. **Resource limits on services**: for each application-related systemd unit, check for MemoryMax/CPUQuota

## Output format
Group by section (Security / Stability). For each check: one line with status icon, check name, and finding. Expand on WARN/CRITICAL items with remediation steps.
