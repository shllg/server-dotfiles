---
description: Quick server health overview
---

Give a quick health overview of this server. Be concise — one line per check.

Run these in parallel where possible:

- `tailscale status` — connectivity
- `systemctl --failed` — broken services
- `free -h` — memory
- `df -h` — disk
- `uptime` — load and uptime
- `ss -tlnp` — listening ports
- `journalctl -p err --since "1 hour ago" --no-pager | tail -20` — recent errors

Summarize as a short table. Flag anything that needs attention.
