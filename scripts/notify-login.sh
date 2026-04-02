#!/usr/bin/env bash
# notify-login.sh — PAM session hook to alert on SSH login
# Installed to /usr/local/bin/notify-login by harden.sh
# Called by PAM via /etc/pam.d/sshd

# Only fire on session open (not close)
[[ "${PAM_TYPE:-}" == "open_session" ]] || exit 0

USER="${PAM_USER:-unknown}"
FROM="${PAM_RHOST:-local}"
TTY="${PAM_TTY:-?}"

/usr/local/bin/notify-discord "SSH login" "User: $USER\nFrom: $FROM\nTTY:  $TTY"
