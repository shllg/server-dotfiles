---
description: Apply server hardening measures
---

Review the current server hardening state and apply any missing hardening measures. Work through each category below, check current state, and fix what's needed.

**IMPORTANT**: Confirm with the user before making any network/firewall/SSH changes. Follow the connectivity protection rules in CLAUDE.md.

## SSH Hardening
- Disable password authentication
- Disable root login with password (permit key-only)
- Disable empty passwords
- Set MaxAuthTries to 3
- Disable X11Forwarding
- Set ClientAliveInterval and ClientAliveCountMax for idle timeout
- Ensure only protocol 2

## Firewall
- Set up nftables with default deny inbound
- Allow all traffic on tailscale0 interface
- Allow all traffic on loopback
- Allow established/related connections
- Drop everything else on public interfaces
- **Verify Tailscale connectivity after every change**

## Kernel Hardening (sysctl)
- Disable IP forwarding (unless Tailscale needs it — check first)
- Enable SYN cookies
- Disable ICMP redirects
- Enable reverse path filtering
- Disable core dumps
- Restrict dmesg access
- Restrict kernel pointer exposure

## System
- Ensure unattended-upgrades is installed and configured for security updates
- Set appropriate umask (027)
- Disable unused network protocols (dccp, sctp, rds, tipc)
- Remove or disable unnecessary services
- Configure fail2ban on the public interface (if SSH is exposed publicly as fallback)

## Verification
After each section, verify the changes took effect and nothing is broken. Run `tailscale status` after any network change.
