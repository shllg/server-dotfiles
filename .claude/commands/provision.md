---
description: Provision a server component
argument-hint: <component-name>
---

Provision a component on this server. The user will specify what to install/configure.

Follow these rules strictly:

1. **Pre-flight**: Check what's already installed (`which`, `dpkg -l`, `systemctl status`) — don't reinstall what exists
2. **Plan**: State what you will install, from where, and what config changes you'll make. Wait for user confirmation on anything touching network/firewall/SSH.
3. **Install**: Use official repos or vendor repos with GPG keys. No `curl | bash`. For binaries, verify checksums.
4. **Configure**: 
   - Services bind to Tailscale IP or 127.0.0.1 only
   - Create a systemd unit with Restart=on-failure, resource limits (MemoryMax, CPUQuota), and proper After= ordering
   - Backup existing configs before modifying: `cp <file> <file>.bak-$(date +%s)`
5. **Verify**: Start the service, check it's running, check logs for errors, test functionality end-to-end
6. **Document**: Note the component in the local Claude config (`~/.claude/projects/.../CLAUDE.md`) if it's a permanent addition

$ARGUMENTS
