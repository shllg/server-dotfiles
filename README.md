# Dotfiles

Portable server dotfiles managed with GNU Stow. Clone once, stow everywhere.

This is a **public repo** — servers pull via HTTPS without needing SSH keys or a git account.

## Bootstrap a new server

On a fresh Debian server:

```bash
apt-get update && apt-get install -y git
git clone https://github.com/<you>/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash scripts/debian-bootstrap.sh
```

That's it. The bootstrap script installs everything (zsh, tmux, stow, oh-my-zsh, etc.), stows all configs, sets zsh as default shell, and scaffolds the local Claude Code config.

## After bootstrap

Fill in the server-specific local files:

```bash
# Server identity for Claude Code
vim ~/.claude/projects/-root-dotfiles/CLAUDE.md

# Git identity for this server
vim ~/.gitconfig.local

# Shell customizations
vim ~/.zshrc.local

# Tmux customizations
vim ~/.tmux.conf.local
```

## Updating

Pull the latest and restow:

```bash
cd ~/dotfiles
git pull
make restow-all
```

No credentials needed — it's a public HTTPS clone.

## Need write access?

If a server needs to push to repos (not just consume dotfiles), see [docs/git-identity-setup.md](docs/git-identity-setup.md). That guide covers SSH keys, GPG signing, and — critically — when and how to revoke keys.

Do not leave write credentials on servers that don't need them.
