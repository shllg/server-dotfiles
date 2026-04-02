#!/usr/bin/env bash
# debian-bootstrap.sh — Initial setup for a fresh Debian server
# Installs core packages, oh-my-zsh, and stows dotfiles.
#
# Usage:
#   bash scripts/debian-bootstrap.sh          # full run
#   bash scripts/debian-bootstrap.sh --dry-run # preview only
set -euo pipefail

# -- Config --------------------------------------------------------------------
DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# Core packages to install via apt
APT_PACKAGES=(
  git
  make
  stow
  zsh
  tmux
  curl
  wget
  htop
  jq
  unzip
)

# -- Colors --------------------------------------------------------------------
c='\033[0;36m' g='\033[0;32m' y='\033[1;33m' r='\033[0m'
info()  { echo -e "${c}:: $*${r}"; }
ok()    { echo -e "${g}   $*${r}"; }
warn()  { echo -e "${y}   $*${r}"; }

# -- Helpers -------------------------------------------------------------------
run() {
  if $DRY_RUN; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

need_install() {
  local missing=()
  for pkg in "${APT_PACKAGES[@]}"; do
    if ! dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
      missing+=("$pkg")
    fi
  done
  echo "${missing[@]}"
}

# -- Main ----------------------------------------------------------------------
echo ""
info "Debian Bootstrap"
echo ""

# 1. Apt packages
info "Checking apt packages..."
missing=$(need_install)
if [[ -n "$missing" ]]; then
  warn "Installing: $missing"
  run apt-get update -qq
  run apt-get install -y $missing
  ok "Packages installed"
else
  ok "All packages already installed"
fi

# 2. Oh My Zsh
info "Checking oh-my-zsh..."
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  warn "Installing oh-my-zsh..."
  if ! $DRY_RUN; then
    # Download first, then execute (no curl|bash)
    omz_installer=$(mktemp)
    curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$omz_installer"
    # --unattended: don't switch shell or start zsh
    # --keep-zshrc: don't overwrite existing .zshrc (stow manages it)
    RUNZSH=no KEEP_ZSHRC=yes sh "$omz_installer" --unattended
    rm -f "$omz_installer"
  else
    echo "  [dry-run] install oh-my-zsh"
  fi
  ok "oh-my-zsh installed"
else
  ok "oh-my-zsh already present"
fi

# 3. TPM (tmux plugin manager)
info "Checking tmux plugin manager (TPM)..."
TPM_DIR="$HOME/.config/tmux/plugins/tpm"
if [[ ! -d "$TPM_DIR" ]]; then
  warn "Installing TPM..."
  if ! $DRY_RUN; then
    mkdir -p "$(dirname "$TPM_DIR")"
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
  else
    echo "  [dry-run] git clone tpm → $TPM_DIR"
  fi
  ok "TPM installed"
  warn "After first tmux start, press prefix+I to install plugins"
else
  ok "TPM already present"
fi

info "Checking default shell..."
current_shell=$(getent passwd "$(whoami)" | cut -d: -f7)
if [[ "$current_shell" != */zsh ]]; then
  warn "Changing default shell to zsh..."
  run chsh -s "$(command -v zsh)"
  ok "Default shell set to zsh"
else
  ok "Already using zsh"
fi

# 4. Stow dotfiles (--no-folding prevents stow from symlinking parent dirs)
info "Stowing dotfiles..."
if [[ -f "$DOTFILES_DIR/Makefile" ]]; then
  run make -C "$DOTFILES_DIR" stow-all
  ok "Dotfiles stowed"
else
  warn "Makefile not found in $DOTFILES_DIR — skipping stow"
fi

# 5. Git identity (.gitconfig.local)
GITCONFIG_LOCAL="$HOME/.gitconfig.local"
info "Checking git identity..."
if [[ ! -f "$GITCONFIG_LOCAL" ]]; then
  if ! $DRY_RUN; then
    echo ""
    echo "   Git needs a name and email for commits on this server."
    echo ""
    git_name=""
    git_email=""
    if [[ -t 0 ]] || [[ -e /dev/tty ]]; then
      read -rp "   Git name  (e.g. John Doe): " git_name </dev/tty 2>/dev/null || true
      read -rp "   Git email (e.g. john@example.com): " git_email </dev/tty 2>/dev/null || true
    fi
    if [[ -n "$git_name" && -n "$git_email" ]]; then
      cat > "$GITCONFIG_LOCAL" << GITEOF
[user]
	name = $git_name
	email = $git_email
GITEOF
      ok "Created $GITCONFIG_LOCAL"
    else
      # Write a skeleton so the user knows to fill it in
      cat > "$GITCONFIG_LOCAL" << 'GITEOF'
# Fill in your git identity for this server
[user]
#	name = Your Name
#	email = you@example.com
GITEOF
      warn "Created skeleton $GITCONFIG_LOCAL — fill in name/email"
    fi
  else
    echo "  [dry-run] create $GITCONFIG_LOCAL"
  fi
else
  ok "Git identity already configured"
fi

# 6. Claude Code local config
# The project path slug matches how Claude Code resolves ~/.claude/projects/<path>/
CLAUDE_PROJECT_DIR="$HOME/.claude/projects/-root-dotfiles"
CLAUDE_LOCAL_MD="$CLAUDE_PROJECT_DIR/CLAUDE.md"
info "Checking Claude Code local config..."
if [[ ! -f "$CLAUDE_LOCAL_MD" ]]; then
  if ! $DRY_RUN; then
    mkdir -p "$CLAUDE_PROJECT_DIR"
    cat > "$CLAUDE_LOCAL_MD" << 'SKELETON'
# Server Context (local — not checked into dotfiles)

## Server Identity
- **Name**: TODO
- **Provider**: TODO (e.g., Hetzner)
- **Purpose**: TODO (e.g., "AI agent orchestrator for night-orch")

## What runs here
- TODO: list services, apps, key systemd units

## Server-specific notes
- TODO: anything unique to this machine (special mounts, cron jobs, etc.)
SKELETON
  else
    echo "  [dry-run] create $CLAUDE_LOCAL_MD"
  fi
  ok "Created skeleton at $CLAUDE_LOCAL_MD"
  warn "Fill in the TODOs above on first Claude Code session"
else
  ok "Local Claude config already exists"
fi

# 7. Hardening
info "Hardening..."
warn "Run 'bash scripts/harden.sh' separately to:"
echo "  - Install & configure Tailscale"
echo "  - Lock SSH to Tailscale only"
echo "  - Enable UFW firewall"
echo "  - Apply kernel hardening"
echo "  Use --dry-run to preview: bash scripts/harden.sh --dry-run"
echo ""

# 8. Summary
info "Done. Installed:"
echo "  git       $(git --version 2>/dev/null | cut -d' ' -f3)"
echo "  make      $(make --version 2>/dev/null | head -1 | grep -oP '[\d.]+')"
echo "  stow      $(stow --version 2>/dev/null | grep -oP '[\d.]+')"
echo "  zsh       $(zsh --version 2>/dev/null | cut -d' ' -f2)"
echo "  tmux      $(tmux -V 2>/dev/null | cut -d' ' -f2)"
echo "  oh-my-zsh $(test -d ~/.oh-my-zsh && echo 'installed' || echo 'missing')"
echo "  tpm       $(test -d ~/.config/tmux/plugins/tpm && echo 'installed' || echo 'missing')"
echo ""
warn "Next steps:"
echo "  - Fill in ~/.claude/projects/-root-dotfiles/CLAUDE.md with server context"
echo "  - Create ~/.zshrc.local for server-specific shell config"
echo "  - Run: bash scripts/harden.sh (Tailscale + security hardening)"
echo "  - Run: bash scripts/verify.sh (check everything is working)"
echo ""
