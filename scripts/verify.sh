#!/usr/bin/env bash
# verify.sh — Post-setup audit for Debian server hardening
# Checks that all hardening steps from harden.sh are active.
#
# Usage:
#   bash scripts/verify.sh
set -euo pipefail

c='\033[0;36m' g='\033[0;32m' rd='\033[0;31m' y='\033[1;33m' r='\033[0m'
pass() { echo -e "${g} [PASS]${r} $*"; }
fail() { echo -e "${rd} [FAIL]${r} $*"; FAILURES=$((FAILURES + 1)); }
warn() { echo -e "${y} [WARN]${r} $*"; }
info() { echo -e "${c}:: $*${r}"; }

FAILURES=0

echo ""
info "Server Hardening Verification"
echo ""

# -- Tailscale -----------------------------------------------------------------
info "Tailscale"
if command -v tailscale &>/dev/null; then
  pass "Tailscale installed"
else
  fail "Tailscale not installed"
fi

if tailscale status &>/dev/null 2>&1; then
  TS_IP=$(tailscale ip -4 2>/dev/null || true)
  pass "Tailscale connected ($TS_IP)"
else
  fail "Tailscale not connected"
fi

# -- SSH -----------------------------------------------------------------------
info "SSH hardening"
if [[ -f /etc/ssh/sshd_config.d/99-hardened.conf ]]; then
  pass "Hardened sshd config present"
else
  fail "Missing /etc/ssh/sshd_config.d/99-hardened.conf"
fi

if [[ -f /etc/ssh/sshd_config.d/98-listen-address.conf ]]; then
  pass "Listen address config present"
else
  fail "Missing /etc/ssh/sshd_config.d/98-listen-address.conf"
fi

if [[ -f /etc/ssh/ssh_host_ed25519_key ]]; then
  pass "ed25519 host key present"
else
  fail "Missing ed25519 host key"
fi

# Check SSH is not listening on 0.0.0.0:22 (Local Address column)
if ss -tlnp | grep ':22' | awk '{print $4}' | grep -q '0.0.0.0:22'; then
  fail "SSH still listening on 0.0.0.0:22 (public)"
else
  pass "SSH not on public interface"
fi

if ss -tlnp | grep ':22' | awk '{print $4}' | grep -q "${TS_IP:-NONE}"; then
  pass "SSH listening on Tailscale IP"
else
  fail "SSH not listening on Tailscale IP"
fi

# Check password auth is disabled
if sshd -T 2>/dev/null | grep -qi 'passwordauthentication yes'; then
  fail "Password authentication still enabled"
else
  pass "Password authentication disabled"
fi

# -- Firewall ------------------------------------------------------------------
info "Firewall"
if command -v ufw &>/dev/null; then
  pass "UFW installed"
else
  fail "UFW not installed"
fi

if ufw status 2>/dev/null | grep -q 'Status: active'; then
  pass "UFW active"
else
  fail "UFW not active"
fi

if ufw status 2>/dev/null | grep -q 'tailscale0'; then
  pass "Tailscale interface allowed"
else
  fail "Tailscale interface not in UFW rules"
fi

# -- Kernel hardening ----------------------------------------------------------
info "Kernel hardening"
if [[ -f /etc/sysctl.d/99-hardened.conf ]]; then
  pass "Sysctl hardening config present"
else
  fail "Missing /etc/sysctl.d/99-hardened.conf"
fi

# Spot-check a few important settings
check_sysctl() {
  local key="$1" expected="$2"
  local actual
  actual=$(sysctl -n "$key" 2>/dev/null || echo "?")
  if [[ "$actual" == "$expected" ]]; then
    pass "$key = $expected"
  else
    fail "$key = $actual (expected $expected)"
  fi
}

check_sysctl net.ipv4.tcp_syncookies 1
check_sysctl net.ipv4.conf.all.rp_filter 1
check_sysctl kernel.dmesg_restrict 1

# -- AppArmor ------------------------------------------------------------------
info "AppArmor"
if command -v apparmor_status &>/dev/null; then
  pass "AppArmor installed"
  enforce_count=$(apparmor_status 2>/dev/null | grep 'profiles are in enforce mode' | grep -oP '^\s*\d+' | tr -d ' ' || echo "0")
  if [[ -n "$enforce_count" && "$enforce_count" -gt 0 ]]; then
    pass "$enforce_count profiles in enforce mode"
  else
    fail "No AppArmor profiles in enforce mode"
  fi
else
  fail "AppArmor not installed"
fi

# -- Needrestart ---------------------------------------------------------------
info "Needrestart"
if command -v needrestart &>/dev/null; then
  pass "Needrestart installed"
else
  fail "Needrestart not installed"
fi

if [[ -f /etc/needrestart/conf.d/99-auto.conf ]]; then
  pass "Needrestart auto-mode configured"
else
  fail "Needrestart auto-mode not configured"
fi

# -- Time sync -----------------------------------------------------------------
info "Time sync"
if timedatectl show 2>/dev/null | grep -q 'NTPSynchronized=yes'; then
  pass "NTP synchronized"
else
  warn "NTP not yet synchronized"
fi

# -- Journald ------------------------------------------------------------------
info "Journald"
if [[ -f /etc/systemd/journald.conf.d/99-size-cap.conf ]]; then
  pass "Journald size cap configured"
else
  fail "Journald size cap not configured"
fi

# -- Unattended upgrades -------------------------------------------------------
info "Unattended upgrades"
if dpkg -l unattended-upgrades 2>/dev/null | grep -q '^ii'; then
  pass "Unattended-upgrades installed"
else
  fail "Unattended-upgrades not installed"
fi

# -- Notifications -------------------------------------------------------------
info "Notifications"
if [[ -f /etc/server-notifications.conf ]]; then
  pass "Notification config present"
  perms=$(stat -c %a /etc/server-notifications.conf)
  if [[ "$perms" == "600" ]]; then
    pass "Notification config permissions (600)"
  else
    fail "Notification config permissions: $perms (expected 600)"
  fi
else
  warn "No notification config (/etc/server-notifications.conf)"
fi

if [[ -x /usr/local/bin/notify-discord ]]; then
  pass "notify-discord installed"
else
  fail "notify-discord not installed"
fi

if [[ -x /usr/local/bin/check-disk ]]; then
  pass "check-disk installed"
else
  fail "check-disk not installed"
fi

if [[ -f /etc/cron.d/check-disk ]]; then
  pass "Disk monitoring cron active"
else
  fail "Disk monitoring cron missing"
fi

if [[ -x /usr/local/bin/notify-login ]]; then
  pass "notify-login installed"
else
  fail "notify-login not installed"
fi

if grep -q 'notify-login' /etc/pam.d/sshd 2>/dev/null; then
  pass "SSH login notifications enabled (PAM)"
else
  fail "SSH login notifications not in PAM"
fi

# -- Stow packages -------------------------------------------------------------
info "Stow packages"
for pkg in git ssh tmux zsh; do
  if [[ -d "$HOME/dotfiles/stow/$pkg" ]]; then
    pass "Package $pkg available"
  else
    warn "Package $pkg not found in stow/"
  fi
done

# -- Summary -------------------------------------------------------------------
echo ""
if [[ $FAILURES -eq 0 ]]; then
  echo -e "${g}All checks passed.${r}"
else
  echo -e "${rd}$FAILURES check(s) failed.${r}"
fi
echo ""

exit $FAILURES
