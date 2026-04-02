# dotfiles

Portable server dotfiles and hardening for Debian servers. Managed with GNU Stow.

This is a **public repo** -- servers pull via HTTPS without needing SSH keys or a git account.

## New server setup

```bash
# 1. Clone
apt-get update && apt-get install -y git
git clone https://github.com/<you>/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 2. Bootstrap (packages, oh-my-zsh, TPM, stow all configs)
bash scripts/debian-bootstrap.sh

# 3. Install and authenticate Tailscale
tailscale up

# 4. Harden (Tailscale must be connected first)
bash scripts/harden.sh

# 5. In a NEW terminal, verify SSH works via Tailscale
ssh root@$(tailscale ip -4)

# 6. Once verified, restart sshd to lock down
systemctl restart sshd

# 7. Verify everything
bash scripts/verify.sh
```

## What each step does

### `debian-bootstrap.sh`

- Installs core packages (git, make, stow, zsh, tmux, curl, etc.)
- Installs oh-my-zsh and TPM (tmux plugin manager)
- Sets zsh as default shell
- Stows all dotfile packages
- Creates `~/.gitconfig.local` with your name/email (interactive prompt)
- Creates Claude Code local config skeleton

### `harden.sh`

| Step | What |
|------|------|
| 1 | **Tailscale** -- install and verify connection |
| 2 | **SSH** -- key-only auth, Tailscale IP only, strong ciphers, ed25519 host key |
| 3 | **UFW** -- deny all incoming, allow tailscale0 + port 41641/udp |
| 4 | **Sysctl** -- anti-spoofing, SYN cookies, no ICMP redirects, restricted dmesg/ptrace |
| 5 | **AppArmor** -- enforce all profiles |
| 6 | **Needrestart** -- auto-restart services after library updates |
| 7 | **Timesyncd + journald + unattended-upgrades** -- NTP, 500M log cap, security auto-updates |
| 8 | **Notifications** -- Discord webhook for disk alerts (hourly) and SSH login alerts |
| 9 | **Fail2ban** -- optional, interactive prompt (for public-facing servers) |

### `verify.sh`

Post-setup check that validates all hardening is active. Run anytime to audit.

## Stow packages

| Package | What | Local override |
|---------|------|----------------|
| `git` | `.gitconfig` -- defaults, aliases | `~/.gitconfig.local` |
| `ssh` | `.ssh/config` -- hardened client, multiplexing | `~/.ssh/config.local` |
| `tmux` | `.config/tmux/tmux.conf` -- TPM, vim keys, status bar | `~/.config/tmux/tmux.local.conf` |
| `zsh` | `.zshrc` + `.zshenv` -- oh-my-zsh, aliases, history | `~/.zshrc.local` |

### Stow commands

```bash
make list                    # show available packages
make stow PACKAGE=git        # install one package
make stow-all                # install all
make restow-all              # re-apply all (after updating dotfiles)
make unstow PACKAGE=git      # remove one
make clean-links             # remove broken symlinks
make install-scripts         # re-install notification scripts to /usr/local/bin
```

## Structure

```
dotfiles/
├── CLAUDE.md                      # Claude Code project instructions
├── Makefile                       # stow management + install-scripts
├── scripts/
│   ├── debian-bootstrap.sh        # initial server setup
│   ├── harden.sh                  # security hardening
│   ├── verify.sh                  # post-setup audit
│   ├── notify-discord.sh          # Discord webhook helper
│   ├── check-disk.sh              # disk usage monitoring
│   └── notify-login.sh            # SSH login notification (PAM)
└── stow/
    ├── git/.gitconfig
    ├── ssh/.ssh/config
    ├── tmux/.config/tmux/
    └── zsh/.zshrc, .zshenv
```

## Adding a new stow package

1. Create `stow/<name>/` mirroring the home directory structure
2. Add a `.local` include/source mechanism in the config
3. Optionally add `stow/<name>/notes.sh` for pre-stow setup (auto-run by `make stow`)
4. Add `.stow-local-ignore` if the package has non-config files (like `notes.sh`)
5. Test with `make stow PACKAGE=<name>`

## Updating on an existing server

```bash
cd ~/dotfiles
git pull
make restow-all              # re-apply configs
make install-scripts         # update notification scripts
```

## Need write access?

If a server needs to push to repos (not just consume dotfiles), see [docs/git-identity-setup.md](docs/git-identity-setup.md). That guide covers SSH keys, GPG signing, and when/how to revoke keys.

Do not leave write credentials on servers that don't need them.

## Rollback (if locked out)

Use provider console (e.g. Hetzner rescue mode):

```bash
rm /etc/ssh/sshd_config.d/99-hardened.conf
rm /etc/ssh/sshd_config.d/98-listen-address.conf
ufw disable
systemctl restart sshd
```
