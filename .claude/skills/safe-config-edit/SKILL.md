---
name: safe-config-edit
description: >-
  Use this skill when editing system configuration files in /etc/, modifying
  systemd units, changing sshd_config, editing firewall rules, modifying
  package sources, changing PAM configuration, editing crontabs, or any
  file whose misconfiguration could break the system or lock out access.
  Also trigger when the user says "configure", "set up", or "change config".
---

# Safe Configuration Editing

When modifying any system configuration file, follow this protocol. A bad config edit can lock you out of the server or break services.

## Before editing

1. **Backup the file** before any modification:
   ```bash
   cp <file> <file>.bak-$(date +%s)
   ```

2. **Understand the current state** — read the file and relevant service status before changing anything.

3. **State the plan** — tell the user:
   - What you're changing
   - Why
   - What the rollback step is (restore from backup)

## Critical files — extra caution

These files require explicit user approval before modification:

| File/Path | Risk |
|-----------|------|
| `/etc/ssh/sshd_config` | Bad config = locked out of SSH |
| `/etc/nftables.conf`, iptables rules | Bad rule = locked out entirely |
| `/etc/resolv.conf`, `/etc/systemd/resolved.conf` | Bad DNS = nothing works |
| `/etc/fstab` | Bad mount = won't boot |
| `/etc/pam.d/*` | Bad PAM = can't authenticate |
| `/etc/systemd/system/*.service` | Bad unit = service won't start |
| Tailscale config | Bad config = locked out entirely |

For these files: **always ask before applying changes**, even if the user asked you to "just do it."

## After editing

1. **Validate syntax** if the tool provides it:
   - `sshd -t` for SSH config
   - `nft -c -f /etc/nftables.conf` for firewall
   - `systemd-analyze verify <unit>` for systemd units
   - `visudo -c` for sudoers
   - `nginx -t` for nginx

2. **Apply the change** (reload service, `systemctl daemon-reload`, etc.)

3. **Verify it worked** — check service status, test connectivity, confirm expected behavior.

4. **Verify you didn't break access** — for any network-adjacent config, run `tailscale status` after applying.

## Rollback

If something goes wrong:
```bash
cp <file>.bak-<timestamp> <file>
# Then reload/restart the relevant service
```

Keep backups until the next change is verified working.
