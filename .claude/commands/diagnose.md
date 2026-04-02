---
description: Diagnose a misbehaving service or symptom
argument-hint: <service-or-symptom>
---

Systematically investigate a problem on this server. The user provides either a systemd unit name or a symptom description.

If a specific unit is given, use that. If a symptom is given (e.g., "port 8080 not responding"), identify the relevant unit(s) first. If nothing is given, start with `systemctl --failed`.

## Investigation order (do not skip steps)

1. **Unit state**: `systemctl status <unit>` — note exit code, active state, how long it's been in that state
2. **Recent logs**: `journalctl -u <unit> -n 150 --no-pager` — look for errors, panics, tracebacks
3. **Full unit definition**: `systemctl cat <unit>` — show the unit file including drop-in overrides
4. **Dependencies**: Check `After=`, `Requires=`, `Wants=` — are the dependency units actually running?
5. **Resource limits**: Check for `MemoryMax`, `CPUQuota` in the unit. Then check `journalctl -k | grep -i oom` for OOM kills
6. **File permissions**: Check that `ExecStart` binary exists and is executable, `WorkingDirectory` exists, and config files referenced are readable
7. **Port conflicts**: If the service binds a port, check `ss -tlnp | grep <port>` for conflicts
8. **Environment**: Check `Environment=` and `EnvironmentFile=` — do referenced env files exist with correct permissions?

## Output

Summarize findings as a numbered list of observations, then provide a diagnosis and recommended fix. If the fix involves restarting a service or changing config, state the commands but **ask before executing**.

$ARGUMENTS
