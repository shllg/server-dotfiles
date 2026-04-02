#!/usr/bin/env bash
# notify-discord.sh — Send a message to Discord via webhook
# Installed to /usr/local/bin/notify-discord by harden.sh
#
# Usage:
#   notify-discord "Server rebooted"
#   notify-discord "Disk alert" "Root partition at 92%"
#   echo "details" | notify-discord "Title"
set -euo pipefail

CONF="/etc/server-notifications.conf"
[[ -f "$CONF" ]] || { echo "Missing $CONF" >&2; exit 1; }
source "$CONF"
[[ -n "${DISCORD_WEBHOOK:-}" ]] || { echo "DISCORD_WEBHOOK not set in $CONF" >&2; exit 1; }

TITLE="${1:-Notification}"
BODY="${2:-}"

# If no body arg, read from stdin (with timeout so it doesn't hang)
if [[ -z "$BODY" ]] && [[ ! -t 0 ]]; then
  BODY=$(timeout 5 cat || true)
fi

HOSTNAME=$(hostname -f 2>/dev/null || hostname)

# Build message
if [[ -n "$BODY" ]]; then
  MSG="**[$HOSTNAME] $TITLE**\n\`\`\`\n$BODY\n\`\`\`"
else
  MSG="**[$HOSTNAME] $TITLE**"
fi

# Send (silent, fire-and-forget)
curl -s -o /dev/null -H "Content-Type: application/json" \
  -d "{\"content\":\"$MSG\"}" \
  "$DISCORD_WEBHOOK" 2>/dev/null || true
