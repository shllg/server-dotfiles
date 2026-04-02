#!/usr/bin/env bash
# check-disk.sh — Alert via Discord when disk usage exceeds threshold
# Installed to /usr/local/bin/check-disk by harden.sh
# Called by cron every hour
set -euo pipefail

THRESHOLD="${1:-85}"

alert=""
while IFS= read -r line; do
  usage=$(echo "$line" | awk '{print $5}' | tr -d '%')
  mount=$(echo "$line" | awk '{print $6}')
  if [[ "$usage" -ge "$THRESHOLD" ]]; then
    alert+="$mount: ${usage}% used\n"
  fi
done < <(df -h --output=pcent,target -x tmpfs -x devtmpfs -x overlay | tail -n +2)

if [[ -n "$alert" ]]; then
  /usr/local/bin/notify-discord "Disk usage warning (>=${THRESHOLD}%)" "$alert"
fi
