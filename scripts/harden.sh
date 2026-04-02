#!/usr/bin/env bash
# harden.sh — Server hardening for Debian + Tailscale
# Installs Tailscale, locks down SSH, enables firewall, applies kernel
# hardening, sets up monitoring and notifications.
#
# Usage:
#   sudo bash scripts/harden.sh              # full run
#   sudo bash scripts/harden.sh --dry-run    # preview only
#
# ⚠️  WARNING: This script restricts SSH to Tailscale only.
#    Make sure Tailscale is authenticated and working before rebooting.
#    If Tailscale goes down, you lose SSH access entirely.
#
# Rollback:
#   sudo ufw disable
#   sudo rm /etc/ssh/sshd_config.d/99-hardened.conf
#   sudo rm /etc/ssh/sshd_config.d/98-listen-address.conf
#   sudo systemctl disable wait-for-tailscale.service
#   sudo rm /etc/systemd/system/wait-for-tailscale.service
#   sudo rm -rf /etc/systemd/system/ssh.service.d
#   sudo systemctl daemon-reload
#   sudo systemctl restart sshd
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# -- Config --------------------------------------------------------------------
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# -- Colors / helpers ----------------------------------------------------------
c='\033[0;36m' g='\033[0;32m' y='\033[1;33m' rd='\033[0;31m' r='\033[0m'
info()  { echo -e "${c}:: $*${r}"; }
ok()    { echo -e "${g}   $*${r}"; }
warn()  { echo -e "${y}   $*${r}"; }
err()   { echo -e "${rd}!! $*${r}"; }

run() {
  if $DRY_RUN; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

ask_yn() {
  # ask_yn "prompt" -> returns 0 for yes, 1 for no
  local prompt="$1"
  if $DRY_RUN; then
    echo "  [dry-run] would ask: $prompt [y/N]"
    return 1
  fi
  if [[ -t 0 ]]; then
    local answer=""
    read -rp "   $prompt [y/N] " answer || return 1
    [[ "$answer" =~ ^[Yy] ]]
  elif [[ -e /dev/tty ]]; then
    local answer=""
    read -t 30 -rp "   $prompt [y/N] " answer </dev/tty 2>/dev/null || return 1
    [[ "$answer" =~ ^[Yy] ]]
  else
    warn "No TTY available — skipping interactive prompt: $prompt"
    return 1
  fi
}

bail() { err "$1"; exit 1; }

[[ $EUID -eq 0 ]] || bail "Must run as root"

echo ""
info "Server Hardening"
echo ""

# ==============================================================================
# 1. TAILSCALE
# ==============================================================================
info "[1/9] Tailscale"

if command -v tailscale &>/dev/null; then
  ok "Tailscale already installed"
else
  warn "Installing Tailscale..."
  if ! $DRY_RUN; then
    ts_installer=$(mktemp)
    curl -fsSL https://tailscale.com/install.sh -o "$ts_installer"
    bash "$ts_installer"
    rm -f "$ts_installer"
  else
    echo "  [dry-run] download and run Tailscale installer"
  fi
  ok "Tailscale installed"
fi

# Check if Tailscale is up
if ! $DRY_RUN; then
  if ! tailscale status &>/dev/null; then
    warn "Tailscale is installed but not connected."
    warn "Run: tailscale up"
    warn "Then re-run this script."
    bail "Tailscale must be connected before hardening SSH."
  fi
  TS_IP=$(tailscale ip -4 2>/dev/null || true)
  if [[ -z "$TS_IP" ]]; then
    bail "Could not determine Tailscale IPv4 address. Is Tailscale up?"
  fi
  ok "Tailscale connected: $TS_IP"
else
  echo "  [dry-run] verify Tailscale is connected"
  TS_IP="100.x.x.x"
fi

# ==============================================================================
# 2. HARDEN SSHD
# ==============================================================================
info "[2/9] SSH hardening"

## Ensure ed25519 host key exists (required by HostKeyAlgorithms restriction)
ED25519_KEY="/etc/ssh/ssh_host_ed25519_key"
if [[ ! -f "$ED25519_KEY" ]]; then
  warn "Generating ed25519 host key..."
  if ! $DRY_RUN; then
    ssh-keygen -t ed25519 -f "$ED25519_KEY" -N ""
    ok "ed25519 host key generated"
  else
    echo "  [dry-run] ssh-keygen -t ed25519 -f $ED25519_KEY"
  fi
else
  ok "ed25519 host key present"
fi

SSHD_HARDENED="/etc/ssh/sshd_config.d/99-hardened.conf"

if [[ -f "$SSHD_HARDENED" ]]; then
  ok "Hardened sshd config already in place"
else
  warn "Writing $SSHD_HARDENED"
  if ! $DRY_RUN; then
    cat > "$SSHD_HARDENED" << 'SSHEOF'
# Hardened SSH configuration — managed by dotfiles/scripts/harden.sh
# Drop-in file: /etc/ssh/sshd_config.d/99-hardened.conf

# -- Authentication ------------------------------------------------------------
PermitRootLogin prohibit-password
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
MaxAuthTries 3
MaxSessions 3
LoginGraceTime 20

# -- Security ------------------------------------------------------------------
PermitEmptyPasswords no
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
PrintMotd no
PermitUserEnvironment no
DisableForwarding yes

# -- Strong crypto only --------------------------------------------------------
KexAlgorithms mlkem768x25519-sha256,sntrup761x25519-sha512,sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
HostKeyAlgorithms ssh-ed25519

# -- Logging -------------------------------------------------------------------
LogLevel VERBOSE
SSHEOF

    cat > /etc/ssh/sshd_config.d/98-listen-address.conf << LISTENEOF
# Auto-generated by harden.sh — Tailscale listen address
# Regenerate with: harden.sh or manually update
ListenAddress $TS_IP
ListenAddress 127.0.0.1
LISTENEOF

    ok "sshd hardened config written"

    if sshd -t; then
      ok "sshd config validation passed"
    else
      err "sshd config validation FAILED — removing hardened config"
      rm -f "$SSHD_HARDENED" /etc/ssh/sshd_config.d/98-listen-address.conf
      bail "Fix the sshd config and re-run"
    fi
  else
    echo "  [dry-run] write $SSHD_HARDENED"
    echo "  [dry-run] write /etc/ssh/sshd_config.d/98-listen-address.conf (ListenAddress $TS_IP)"
  fi
fi

# -- Boot-order resilience: sshd waits for Tailscale IP -----------------------
info "SSH ↔ Tailscale boot ordering"

WAIT_FOR_TS="/etc/systemd/system/wait-for-tailscale.service"
SSHD_DROPIN_DIR="/etc/systemd/system/ssh.service.d"
SSHD_DROPIN="$SSHD_DROPIN_DIR/wait-for-tailscale.conf"

if [[ -f "$WAIT_FOR_TS" ]] && [[ -f "$SSHD_DROPIN" ]]; then
  ok "Boot-order units already in place"
else
  if ! $DRY_RUN; then
    # Oneshot service that blocks until Tailscale has an IPv4 address
    cat > "$WAIT_FOR_TS" << 'WAITEOF'
# wait-for-tailscale.service — managed by dotfiles/scripts/harden.sh
# Blocks until tailscale ip -4 returns an address (up to 90s).
# sshd depends on this so it doesn't try to bind the Tailscale IP
# before the interface is ready after a reboot.
[Unit]
Description=Wait for Tailscale IP to be available
After=tailscaled.service
Requires=tailscaled.service

[Service]
Type=oneshot
# Poll every 2s for up to 90s (45 attempts)
ExecStart=/bin/bash -c '\
  for i in $(seq 1 45); do \
    if /usr/bin/tailscale ip -4 >/dev/null 2>&1; then \
      echo "Tailscale IP ready: $(/usr/bin/tailscale ip -4)"; \
      exit 0; \
    fi; \
    echo "Waiting for Tailscale IP... (attempt $i/45)"; \
    sleep 2; \
  done; \
  echo "ERROR: Tailscale IP not available after 90s"; \
  exit 1'
TimeoutStartSec=120
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
WAITEOF
    ok "Installed $WAIT_FOR_TS"

    # Drop-in for ssh.service: wait for Tailscale + add RestartSec safety net
    mkdir -p "$SSHD_DROPIN_DIR"
    cat > "$SSHD_DROPIN" << 'DROPEOF'
# wait-for-tailscale.conf — managed by dotfiles/scripts/harden.sh
# Makes sshd wait for the Tailscale IP before starting, and adds
# a restart delay as a safety net.
[Unit]
After=wait-for-tailscale.service
Requires=wait-for-tailscale.service

[Service]
RestartSec=5
DROPEOF
    ok "Installed $SSHD_DROPIN"

    systemctl daemon-reload
    systemctl enable wait-for-tailscale.service
    ok "Boot ordering configured: sshd waits for Tailscale IP"
  else
    echo "  [dry-run] install $WAIT_FOR_TS (polls for tailscale IP, 90s timeout)"
    echo "  [dry-run] install $SSHD_DROPIN (After=wait-for-tailscale.service + RestartSec=5)"
    echo "  [dry-run] systemctl enable wait-for-tailscale.service"
  fi
fi

# ==============================================================================
# 3. FIREWALL (UFW)
# ==============================================================================
info "[3/9] Firewall (UFW)"

if ! command -v ufw &>/dev/null; then
  warn "Installing ufw..."
  run apt-get update -qq
  run apt-get install -y ufw
fi

if ! $DRY_RUN; then
  ufw --force reset >/dev/null 2>&1

  ufw default deny incoming
  ufw default allow outgoing

  # Allow all traffic on Tailscale interface
  ufw allow in on tailscale0
  # Tailscale direct connection port
  ufw allow 41641/udp comment "Tailscale direct"

  ufw --force enable
  ok "UFW enabled"
  ufw status verbose
else
  echo "  [dry-run] ufw default deny incoming, allow outgoing"
  echo "  [dry-run] ufw allow in on tailscale0"
  echo "  [dry-run] ufw allow 41641/udp (Tailscale direct connections)"
  echo "  [dry-run] ufw enable"
fi

# ==============================================================================
# 4. KERNEL HARDENING (sysctl)
# ==============================================================================
info "[4/9] Kernel hardening (sysctl)"

SYSCTL_HARDENED="/etc/sysctl.d/99-hardened.conf"

if [[ -f "$SYSCTL_HARDENED" ]]; then
  ok "Sysctl hardening already in place"
else
  warn "Writing $SYSCTL_HARDENED"
  if ! $DRY_RUN; then
    cat > "$SYSCTL_HARDENED" << 'SYSEOF'
# Kernel hardening — managed by dotfiles/scripts/harden.sh

# -- Network -------------------------------------------------------------------
# Tailscale needs ip_forward=1 for subnet routing / exit nodes.
# Set to 0 if you don't use those features.
net.ipv4.ip_forward = 1

# Ignore ICMP redirects (MITM protection)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Don't send ICMP redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Ignore source-routed packets
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Enable SYN flood protection
net.ipv4.tcp_syncookies = 1

# Log suspicious packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore broadcast pings
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Protect against bad ICMP error messages
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Enable reverse path filtering (anti-spoofing)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# -- Kernel --------------------------------------------------------------------
# Restrict dmesg to root
kernel.dmesg_restrict = 1

# Restrict kernel pointer exposure
kernel.kptr_restrict = 2

# Disable magic SysRq (except sync + reboot: 176)
kernel.sysrq = 176

# Restrict ptrace to parent processes only
kernel.yama.ptrace_scope = 1

# Limit core dumps
fs.suid_dumpable = 0
SYSEOF

    sysctl --system >/dev/null 2>&1
    ok "Sysctl hardening applied"
  else
    echo "  [dry-run] write $SYSCTL_HARDENED"
    echo "  [dry-run] sysctl --system"
  fi
fi

# ==============================================================================
# 5. APPARMOR
# ==============================================================================
info "[5/9] AppArmor"

if ! command -v apparmor_status &>/dev/null; then
  warn "Installing AppArmor..."
  run apt-get update -qq
  run apt-get install -y apparmor apparmor-utils
fi

if ! $DRY_RUN; then
  # Enable and start AppArmor
  systemctl enable apparmor
  systemctl start apparmor

  # Set all installed profiles to enforce mode
  aa-enforce /etc/apparmor.d/* 2>/dev/null || true

  PROFILES_STATUS=$(apparmor_status 2>/dev/null | head -5)
  ok "AppArmor active"
  echo "$PROFILES_STATUS" | while IFS= read -r line; do echo "     $line"; done
else
  echo "  [dry-run] install apparmor apparmor-utils"
  echo "  [dry-run] enable + enforce all profiles"
fi

# ==============================================================================
# 6. NEEDRESTART
# ==============================================================================
info "[6/9] Needrestart"

if ! command -v needrestart &>/dev/null; then
  warn "Installing needrestart..."
  run apt-get update -qq
  run apt-get install -y needrestart
fi

# Configure automatic restart mode
NEEDRESTART_CONF="/etc/needrestart/conf.d/99-auto.conf"
if [[ ! -f "$NEEDRESTART_CONF" ]]; then
  if ! $DRY_RUN; then
    mkdir -p /etc/needrestart/conf.d
    cat > "$NEEDRESTART_CONF" << 'NREOF'
# Auto-restart services after library updates (no prompting)
# a = automatic, l = list only, i = interactive
$nrconf{restart} = 'a';
NREOF
    ok "Needrestart set to automatic mode"
  else
    echo "  [dry-run] write $NEEDRESTART_CONF (auto-restart mode)"
  fi
else
  ok "Needrestart already configured"
fi

# ==============================================================================
# 7. TIME SYNC + JOURNALD + UNATTENDED UPGRADES
# ==============================================================================
info "[7/9] Time sync, journald, unattended-upgrades"

# -- timesyncd -----------------------------------------------------------------
if ! $DRY_RUN; then
  systemctl enable systemd-timesyncd
  systemctl start systemd-timesyncd
  if timedatectl show 2>/dev/null | grep -q 'NTPSynchronized=yes'; then
    ok "Time synced via NTP"
  else
    warn "NTP enabled but not yet synchronized (may take a moment)"
  fi
else
  echo "  [dry-run] enable systemd-timesyncd"
fi

# -- journald size cap ---------------------------------------------------------
JOURNALD_CONF="/etc/systemd/journald.conf.d/99-size-cap.conf"
if [[ ! -f "$JOURNALD_CONF" ]]; then
  if ! $DRY_RUN; then
    mkdir -p /etc/systemd/journald.conf.d
    cat > "$JOURNALD_CONF" << 'JEOF'
[Journal]
SystemMaxUse=500M
MaxFileSec=1week
JEOF
    systemctl restart systemd-journald
    ok "Journald capped at 500M"
  else
    echo "  [dry-run] cap journald at 500M"
  fi
else
  ok "Journald size cap already configured"
fi

# -- unattended-upgrades -------------------------------------------------------
if ! dpkg -l unattended-upgrades 2>/dev/null | grep -q '^ii'; then
  warn "Installing unattended-upgrades..."
  run apt-get update -qq
  run apt-get install -y unattended-upgrades
fi

UNATTENDED_CONF="/etc/apt/apt.conf.d/51custom-unattended"
if [[ ! -f "$UNATTENDED_CONF" ]]; then
  if ! $DRY_RUN; then
    cat > "$UNATTENDED_CONF" << 'UEOF'
// Security updates only, no automatic reboot
Unattended-Upgrade::Automatic-Reboot "false";
// Remove unused kernel packages after upgrade
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
// Remove unused auto-installed dependencies
Unattended-Upgrade::Remove-Unused-Dependencies "true";
UEOF
    ok "Unattended-upgrades configured (security only, no auto-reboot)"
  else
    echo "  [dry-run] configure unattended-upgrades"
  fi
else
  ok "Unattended-upgrades already configured"
fi

# ==============================================================================
# 8. NOTIFICATIONS (Discord)
# ==============================================================================
info "[8/9] Notifications"

NOTIF_CONF="/etc/server-notifications.conf"

if [[ -f "$NOTIF_CONF" ]]; then
  ok "Notification config already exists"
else
  if ! $DRY_RUN; then
    echo ""
    echo "   Discord webhook for server alerts (disk, login, etc.)"
    echo "   Get one from: Server Settings → Integrations → Webhooks"
    echo ""
    read -rp "   Discord webhook URL (leave empty to skip): " webhook_url </dev/tty

    if [[ -n "$webhook_url" ]]; then
      echo "DISCORD_WEBHOOK=\"$webhook_url\"" > "$NOTIF_CONF"
      chmod 0600 "$NOTIF_CONF"
      ok "Webhook saved to $NOTIF_CONF"

      # Test it
      if curl -s -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" \
           -d '{"content":"✅ Server notifications connected."}' \
           "$webhook_url" | grep -q '204'; then
        ok "Test message sent — check your Discord channel"
      else
        warn "Webhook test failed — check the URL"
      fi
    else
      warn "Skipped — no notifications configured"
    fi
  else
    echo "  [dry-run] prompt for Discord webhook URL"
  fi
fi

# -- Install helper scripts ----------------------------------------------------
install_script() {
  local src="$1" dest="$2"
  if [[ -f "$SCRIPT_DIR/$src" ]]; then
    cp "$SCRIPT_DIR/$src" "$dest"
    chmod 0755 "$dest"
    ok "Installed $dest"
  else
    warn "Missing $SCRIPT_DIR/$src — skipping"
  fi
}

if [[ -f "$NOTIF_CONF" ]]; then
  run install_script notify-discord.sh /usr/local/bin/notify-discord
  run install_script check-disk.sh     /usr/local/bin/check-disk
  run install_script notify-login.sh   /usr/local/bin/notify-login

  # -- Disk monitoring cron (hourly) -------------------------------------------
  CRON_DISK="/etc/cron.d/check-disk"
  if [[ ! -f "$CRON_DISK" ]]; then
    if ! $DRY_RUN; then
      cat > "$CRON_DISK" << 'CRONEOF'
# Check disk usage every hour, alert if any partition > 85%
0 * * * * root /usr/local/bin/check-disk 85
CRONEOF
      ok "Disk monitoring cron installed (hourly, >85% threshold)"
    else
      echo "  [dry-run] install disk monitoring cron"
    fi
  else
    ok "Disk monitoring cron already exists"
  fi

  # -- SSH login notification via PAM ------------------------------------------
  PAM_SSHD="/etc/pam.d/sshd"
  PAM_LINE="session optional pam_exec.so /usr/local/bin/notify-login"
  if [[ -f "$PAM_SSHD" ]] && ! grep -q "notify-login" "$PAM_SSHD"; then
    if ! $DRY_RUN; then
      echo "" >> "$PAM_SSHD"
      echo "# Login notification — managed by dotfiles/scripts/harden.sh" >> "$PAM_SSHD"
      echo "$PAM_LINE" >> "$PAM_SSHD"
      ok "SSH login notifications enabled via PAM"
    else
      echo "  [dry-run] add notify-login to $PAM_SSHD"
    fi
  else
    ok "SSH login notification already configured"
  fi
else
  warn "No notification config — skipping Discord alerts, disk monitoring, login notifications"
fi

# ==============================================================================
# 9. FAIL2BAN (optional — for public-facing servers)
# ==============================================================================
info "[9/9] Fail2ban (optional)"

if dpkg -l fail2ban 2>/dev/null | grep -q '^ii'; then
  ok "Fail2ban already installed"
else
  echo ""
  echo "   Fail2ban protects public-facing services against brute-force attacks."
  echo "   If all ports are behind Tailscale (no public-facing services), skip this."
  echo ""
  if ask_yn "Install fail2ban? (y = install, N = skip)"; then
    run apt-get update -qq
    run apt-get install -y fail2ban

    F2B_LOCAL="/etc/fail2ban/jail.local"
    if [[ ! -f "$F2B_LOCAL" ]]; then
      if ! $DRY_RUN; then
        cat > "$F2B_LOCAL" << 'F2BEOF'
# Fail2ban configuration — managed by dotfiles/scripts/harden.sh
# Add per-service jails in /etc/fail2ban/jail.d/

[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
# Ban action: use UFW integration
banaction = ufw

[sshd]
enabled = true
port    = ssh
F2BEOF
        systemctl enable fail2ban
        systemctl restart fail2ban
        ok "Fail2ban installed and enabled"
      fi
    else
      ok "Fail2ban jail.local already exists"
    fi
  else
    ok "Skipped"
  fi
fi

# ==============================================================================
# DISABLE UNUSED SERVICES
# ==============================================================================
info "Cleanup: disabling unnecessary services"

for svc in avahi-daemon cups bluetooth; do
  if systemctl is-enabled "$svc" &>/dev/null 2>&1; then
    warn "Disabling $svc"
    run systemctl disable --now "$svc"
  fi
done
ok "Unnecessary services checked"

# ==============================================================================
# SUMMARY
# ==============================================================================
echo ""
info "Hardening complete."
echo ""
echo "  What was done:"
echo "    [1] Tailscale — installed and verified"
echo "    [2] SSH — key-only, Tailscale IP only, strong ciphers, boot-order safe"
echo "    [3] UFW — deny all incoming, allow tailscale0 + 41641/udp"
echo "    [4] Kernel — sysctl hardening (anti-spoofing, SYN cookies, etc.)"
echo "    [5] AppArmor — enforcing all profiles"
echo "    [6] Needrestart — auto-restart services after library updates"
echo "    [7] Time sync, journald cap (500M), unattended security upgrades"
echo "    [8] Notifications — Discord alerts for disk usage + SSH logins"
echo "    [9] Fail2ban — optional, for public-facing servers"
echo ""

if ! $DRY_RUN; then
  warn "IMPORTANT — Before disconnecting this session:"
  echo "    1. Open a NEW terminal and verify SSH works via Tailscale IP:"
  echo "       ssh root@$TS_IP"
  echo "    2. If that works, restart sshd to apply listen address change:"
  echo "       sudo systemctl restart sshd"
  echo "    3. Verify again from the NEW terminal."
  echo "    4. Only then close this session."
  echo ""
  warn "If you get locked out:"
  echo "    - Use provider console (Hetzner rescue) to undo changes"
  echo "    - Rollback: remove /etc/ssh/sshd_config.d/99-hardened.conf"
  echo "                remove /etc/ssh/sshd_config.d/98-listen-address.conf"
  echo "                ufw disable"
  echo ""
fi
