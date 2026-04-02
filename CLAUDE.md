# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.
It is checked into git and applies identically on every server.

## IMPORTANT: This file is GENERIC

**DO NOT** add server-specific information to this file. No server names, IPs, hostnames, project descriptions, service lists, or anything that differs between servers.

Server-specific context belongs in `~/.claude/projects/.../CLAUDE.md` (local, not in this repo). The bootstrap script creates a skeleton for that automatically — fill it in on first use.

If you are Claude Code and tempted to edit this file with server-specific details: **stop**. Edit the local Claude config instead.

## Project Overview

**dotfiles** — Portable server dotfiles managed with GNU Stow. Designed to be cloned and applied identically on any Debian server.

## Structure

```
dotfiles/
├── CLAUDE.md
├── Makefile          # stow/unstow/restow/list/stow-all/clean-links
├── scripts/
│   └── debian-bootstrap.sh   # Full initial setup for a fresh Debian server
└── stow/
    ├── git/.gitconfig
    ├── tmux/.tmux.conf
    └── zsh/.zshrc
```

## Dotfiles Rules

### Generic only — no server-specific settings
- Everything in `stow/` must work on any server. No hostnames, IPs, paths to specific apps, or credentials.
- Each config includes a `.local` file for server-specific overrides:
  - `.zshrc` → sources `~/.zshrc.local`
  - `.gitconfig` → includes `~/.gitconfig.local`
  - `.tmux.conf` → sources `~/.tmux.conf.local`
- When adding a new stow package, always add the `.local` include hook.

### Adding a new stow package
1. Create `stow/<name>/` mirroring the home directory structure
2. Add a `.local` include/source mechanism in the config
3. Optionally add `stow/<name>/notes.sh` for pre-install steps (runs before stow)
4. Test with `make stow PACKAGE=<name>`

### Bootstrap script
- `scripts/debian-bootstrap.sh` must stay idempotent (safe to re-run)
- No `curl | bash` — download first, then execute
- Supports `--dry-run` for preview

### Makefile
- Stow commands run from `stow/` subdirectory with `-t $TARGET`
- Packages are auto-discovered from `stow/*/` directories

---

## Operational Rules (apply to all servers)

### Connectivity Protection (CRITICAL)
- **Never** modify iptables/nftables, sshd_config, or Tailscale config without first confirming the change with the user
- **Never** restart networking, sshd, or Tailscale without explicit approval
- Before any network/firewall change: run `tailscale status` and `ss -tlnp` to capture current state
- After any network/firewall change: immediately verify Tailscale is still connected and SSH is reachable
- If a firewall rule is being added, ensure Tailscale interface (tailscale0) traffic is explicitly allowed
- Losing Tailscale = losing all access to this server. There is no fallback.

### Security Posture
- All services bind to Tailscale IP or localhost only — never to 0.0.0.0 or public interfaces
- No passwords anywhere: SSH key-only, token-based auth for APIs
- Every exposed port must be justified and documented
- Prefer systemd socket activation or on-demand services over always-running daemons
- Package installs: use only official Debian repos, vendor repos with GPG-verified keys, or checksummed binaries
- No `curl | bash` installs — always download first, inspect, then execute
- Secrets go in systemd credentials, environment files with 0600 permissions, or a secrets manager — never in config files, CLI args, or environment variables visible in /proc

### Stability
- Every service must have a systemd unit with proper `Restart=`, `After=`, and resource limits (`MemoryMax`, `CPUQuota`)
- Use `systemctl edit` for overrides — never modify vendor unit files directly
- Before installing or upgrading packages: `apt-get update && apt-get --simulate` to preview changes
- Before enabling a new service: verify it starts cleanly with `systemd-analyze verify` and check `journalctl -u <unit>` after start
- Log rotation must be configured for any service writing logs outside of journald
- Filesystem: monitor disk usage; orchestrator worktrees can accumulate — ensure cleanup mechanisms exist
- DNS resolution: always confirm `resolvectl status` is sane after network changes

### Change Discipline
- One concern at a time: don't bundle unrelated changes (e.g., don't add a firewall rule while installing a package)
- For any system config change: state what you're changing, why, and what the rollback is — before doing it
- Take a backup or snapshot of config files before modifying them: `cp <file> <file>.bak-$(date +%s)`
- After provisioning a component, verify it works end-to-end before moving to the next
