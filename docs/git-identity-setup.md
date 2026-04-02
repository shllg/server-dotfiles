# Git Identity & Key Setup

This guide is for servers that need **write access** to repositories (pushing code, signing commits). Most servers only need to pull dotfiles — they do NOT need this setup. See the main README for the simple pull-only bootstrap.

## When you need this

- The server will push commits (e.g., an orchestrator creating PRs)
- You want signed commits from this server
- The server needs private repo access

## SSH key

```bash
apt-get install -y openssh-client
ssh-keygen -t ed25519 -C "servername@purpose"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
```

Use a descriptive comment (`servername@purpose`) so you can identify the key later when revoking.

### Register the SSH key

**GitHub**: https://github.com/settings/keys → "New SSH key"
**Forgejo/Gitea**: Settings → SSH / GPG Keys → "Add Key"

Verify:

```bash
ssh -T git@github.com
ssh -T git@<your-forgejo-host>
```

## GPG key (for commit signing)

```bash
apt-get install -y gnupg
gpg --full-generate-key
```

Choose RSA 4096-bit. Use the same name/email as your git config.

```bash
# Get the key ID
gpg --list-secret-keys --keyid-format=long
# sec   rsa4096/<KEY_ID> ...

# Configure git to sign
git config --global user.signingkey <KEY_ID>
git config --global commit.gpgsign true

# Export public key for your git host
gpg --armor --export <KEY_ID>
```

Register the GPG public key at the same settings page as SSH.

## Key lifecycle — IMPORTANT

Every key you create is an access credential. Treat it like one.

### Scope keys narrowly

- On GitHub, prefer **deploy keys** (per-repo, read-only by default) over account-wide SSH keys whenever possible
- If the server only needs access to specific repos, don't give it your full account key
- Consider GitHub fine-grained personal access tokens with limited repo scope as an alternative to SSH keys

### Track your keys

Keep a record of which servers have which keys. At minimum:

```
Server          Key fingerprint              Git host        Scope           Created
night-orch      SHA256:abc123...             github.com      account-wide    2026-04-01
build-runner    SHA256:def456...             forgejo.local   deploy (repos)  2026-04-02
```

### Revoke keys when

- **Server is decommissioned** — revoke immediately, before destroying the server
- **Server purpose changes** — if it no longer needs write access, revoke and switch to HTTPS pull-only
- **Key may be compromised** — revoke first, investigate later
- **Setup is done** — if you only needed push access temporarily (e.g., to set up a repo), revoke the key once you're done. Don't leave credentials lying around "just in case"

### How to revoke

**GitHub SSH key**: https://github.com/settings/keys → find the key → Delete
**GitHub GPG key**: same page → find the key → Delete
**Forgejo/Gitea**: Settings → SSH / GPG Keys → Delete

Then on the server:

```bash
# Remove the key files
rm ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub

# Remove GPG key
gpg --delete-secret-and-public-key <KEY_ID>
```

### Audit regularly

Periodically check your git host for stale keys:

- GitHub: https://github.com/settings/keys — check "Last used" column
- If a key hasn't been used in months and you don't recognize the server, revoke it
