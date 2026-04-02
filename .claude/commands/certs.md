---
description: TLS certificate inventory and expiry check
---

Inventory all TLS certificates on this server and check their health. Flag anything expiring within 30 days.

## 1. Find certificates

Search these locations for `.pem`, `.crt` files:
- `/etc/ssl/certs/` (skip the system CA bundle symlinks — focus on locally added certs)
- `/etc/letsencrypt/live/`
- `/etc/nginx/`, `/etc/apache2/`, `/etc/caddy/` (if they exist)
- Any cert paths referenced in running service unit files (`systemctl cat <unit>` for TLS-related services)

## 2. Check each certificate

For each certificate found, extract:
```
openssl x509 -in <cert> -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null
```

Calculate days until expiry. Flag:
- **CRITICAL**: expires within 7 days
- **WARN**: expires within 30 days
- **OK**: expires later than 30 days

## 3. Certbot status (if installed)

- `certbot certificates` — list managed certificates
- `systemctl list-timers | grep certbot` — check renewal timer is active
- `certbot renew --dry-run` — test renewal works

## 4. Live verification

For each HTTPS-capable port found in `ss -tlnp`, connect and check the served certificate:
```
echo | openssl s_client -connect 127.0.0.1:<port> -servername <name> 2>/dev/null | openssl x509 -noout -subject -dates
```

Compare with the on-disk certificate — flag mismatches.

## 5. Key/cert pairing

For each cert that has a corresponding `.key` file nearby, verify they match:
```
openssl x509 -noout -modulus -in <cert> | md5sum
openssl rsa -noout -modulus -in <key> | md5sum
```

Flag any mismatches.

## Output

Present as a table:

| Service | Cert path | Subject/SANs | Expires | Days left | Status |
|---------|-----------|--------------|---------|-----------|--------|

Then list any issues found (mismatches, renewal failures, missing timers).
