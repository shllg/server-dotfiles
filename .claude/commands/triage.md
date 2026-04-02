---
description: Capture full system state for incident investigation
argument-hint: [issue-description]
---

Something is wrong or was wrong on this server. Capture system state immediately for investigation. **Do not fix anything yet** — collect evidence first.

## 1. Create triage directory

```
mkdir -p /root/triage-$(date +%Y%m%d-%H%M%S)
```

Save all subsequent command outputs to files in this directory.

## 2. System snapshot (run all in parallel)

- `date -Is` → `timestamp.txt`
- `uptime` → `uptime.txt`
- `free -m` → `memory.txt`
- `df -h` → `disk.txt`
- `ps auxf` → `processes.txt`
- `ss -tlnp` → `ports.txt`
- `ss -s` → `socket-summary.txt`
- `ip addr` → `network.txt`
- `tailscale status` → `tailscale.txt`
- `systemctl --failed` → `failed-units.txt`
- `systemctl list-units --type=service --state=running --no-pager` → `running-services.txt`

## 3. Logs

- `journalctl -p err --since "1 hour ago" --no-pager` → `journal-errors.txt`
- `journalctl -p warning --since "15 min ago" --no-pager` → `journal-warnings-recent.txt`
- `dmesg --time-format=iso | tail -300` → `dmesg.txt` (catches OOM kills, hardware errors, disk errors)

## 4. Resource pressure

- `cat /proc/pressure/cpu /proc/pressure/memory /proc/pressure/io 2>/dev/null` → `pressure.txt`
- `top -bn1 | head -30` → `top.txt`
- `iostat -x 1 3 2>/dev/null` → `iostat.txt` (if sysstat installed)

## 5. Access and activity

- `last -20` → `logins.txt`
- `who` → `who.txt`

## 6. Summary

Print the triage directory path. Then provide a quick assessment:
- What looks abnormal in the collected data?
- Which services or subsystems should be investigated first?
- Any signs of resource exhaustion, crash loops, or network issues?

If the user provided an issue description, focus the assessment on data relevant to that issue.

$ARGUMENTS
