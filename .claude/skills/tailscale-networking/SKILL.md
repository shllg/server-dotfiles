---
name: tailscale-networking
description: >-
  Use this skill when the user asks about networking, ports, firewall rules,
  binding services, exposing endpoints, configuring listen addresses, or mentions
  Tailscale, tailscale0, VPN, private network, or access control. Also trigger
  when any command involves iptables, nftables, ufw, ss, netstat, or when
  configuring a service that opens a port.
---

# Tailscale-Aware Networking

Tailscale is the ONLY way to reach this server. There is no public IP access, no fallback SSH. Losing Tailscale connectivity means losing the server entirely.

## Core principles

1. **Every listening port** must bind to the Tailscale IP (`tailscale ip -4`) or `127.0.0.1` — never `0.0.0.0`
2. **Firewall rules** must always allow the `tailscale0` interface — deny this and you're locked out
3. **Never restart** tailscaled, networking, or sshd without explicit user approval
4. **Always verify** connectivity after any network change

## Before any network change

Capture the current state so you can detect if something breaks:

```bash
tailscale status
ss -tlnp
ip addr show tailscale0
```

## After any network change

Immediately verify — do not proceed to other work until confirmed:

```bash
tailscale status          # must show "Connected" or similar
ss -tlnp                  # ports should match pre-change snapshot
```

If Tailscale shows disconnected after a change, **immediately roll back**.

## Getting the Tailscale IP

```bash
# IPv4
tailscale ip -4

# In config files that need the IP at write time
TSIP=$(tailscale ip -4)
```

## Firewall rules (nftables)

If configuring nftables, the Tailscale interface MUST be allowed:

```nft
chain input {
    type filter hook input priority 0; policy drop;
    iif lo accept
    iif tailscale0 accept              # CRITICAL — never remove this
    ct state established,related accept
    # ... other rules
}
```

## Common service configuration patterns

For services that support bind address:
```
# nginx
listen <tailscale-ip>:8080;

# node/express
app.listen(8080, '<tailscale-ip>');

# generic
bind-address = <tailscale-ip>
```

For services that only support `0.0.0.0` or `127.0.0.1`: bind to `127.0.0.1` and use a reverse proxy or Tailscale Funnel if external access is needed.

## DNS

After any network change, verify DNS still works:

```bash
resolvectl status
dig +short github.com
```
