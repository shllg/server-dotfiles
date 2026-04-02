---
name: systemd-units
description: >-
  Use this skill when the user asks to "create a service", "write a systemd unit",
  "add a systemd timer", "set up a daemon", "make something start on boot",
  mentions systemd, .service files, .timer files, or is configuring any long-running
  process on the server. Also trigger when reviewing or editing existing unit files.
---

# Systemd Unit Authoring

When creating or modifying systemd units on this server, follow these patterns exactly.

## Service units

Every service unit MUST include:

```ini
[Unit]
Description=<clear one-line description>
After=network-online.target
Wants=network-online.target
# Add service-specific dependencies with After= and Requires=

[Service]
Type=<simple|exec|notify|oneshot>
ExecStart=<full path to binary, never relative>
Restart=on-failure
RestartSec=5s

# Hardening — always include these
MemoryMax=<appropriate limit>
CPUQuota=<appropriate limit>
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
ReadWritePaths=<only what's needed>

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=<service-name>

[Install]
WantedBy=multi-user.target
```

## Bind address

Services that listen on a network port MUST bind to the Tailscale IP or 127.0.0.1.
To get the Tailscale IP programmatically:

```bash
tailscale ip -4
```

Never bind to `0.0.0.0` or `::`. If the service doesn't support bind-address configuration, use systemd socket activation or a reverse proxy bound to the Tailscale IP.

## Timer units

For scheduled tasks, prefer systemd timers over cron:

```ini
[Unit]
Description=<what this timer triggers>

[Timer]
OnCalendar=<calendar expression>
Persistent=true
RandomizedDelaySec=60

[Install]
WantedBy=timers.target
```

## Overrides

Never edit vendor unit files. Always use drop-in overrides:

```bash
systemctl edit <unit>
```

This creates `/etc/systemd/system/<unit>.d/override.conf`.

## Verification checklist

After creating or modifying a unit:

1. `systemd-analyze verify <unit>` — catch syntax errors
2. `systemctl daemon-reload`
3. `systemctl start <unit>`
4. `systemctl status <unit>` — verify it started cleanly
5. `journalctl -u <unit> -n 30` — check for errors in logs
6. If it listens on a port: `ss -tlnp | grep <port>` — verify correct bind address
