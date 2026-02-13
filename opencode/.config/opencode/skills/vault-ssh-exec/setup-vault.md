# Vault + sshpass Setup Guide

One-time setup for using the `vault-ssh-exec` skill.

## 1. Install HashiCorp Vault CLI

### Debian/Ubuntu
```bash
sudo apt-get update && sudo apt-get install -y gpg
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y vault
```

### RHEL
```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo dnf install -y vault
```

### Fedora
```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
sudo dnf install -y vault
```

### macOS
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/vault
```

### Arch Linux
```bash
sudo pacman -S vault
```

Verify: `vault --version`

## 2. Install sshpass

The `vault-ssh-exec.sh` script auto-installs sshpass if missing. To install
manually:

```bash
# Debian/Ubuntu
sudo apt-get install -y sshpass

# RHEL/Fedora
sudo dnf install -y sshpass

# macOS (requires third-party tap)
brew install hudochenkov/sshpass/sshpass

# Arch Linux
sudo pacman -S sshpass
```

## 3. Self-Hosted Vault Server (systemd)

Vault runs as a systemd service on your machine. Secrets persist on disk
across reboots. You manually unseal after each restart.

### 3.1 Create directories and config

```bash
sudo mkdir -p /opt/vault/data
sudo mkdir -p /etc/vault.d
```

Create the server config at `/etc/vault.d/vault.hcl`:

```bash
sudo tee /etc/vault.d/vault.hcl > /dev/null <<'EOF'
storage "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_disable = true
}

ui            = true
disable_mlock = true
api_addr      = "http://127.0.0.1:8200"
EOF
```

Lock down permissions:

```bash
sudo chmod 640 /etc/vault.d/vault.hcl
```

> **Note**: `tls_disable = true` is fine for localhost-only. If you ever
> expose Vault on a network interface, enable TLS.

### 3.2 Create the systemd service

```bash
sudo tee /etc/systemd/system/vault.service > /dev/null <<'EOF'
[Unit]
Description=HashiCorp Vault
Documentation=https://developer.hashicorp.com/vault/docs
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF
```

> If `vault` was installed via Homebrew or is at a different path, update
> the `ExecStart` path. Find it with: `which vault`

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable vault
sudo systemctl start vault
```

Verify it's running:

```bash
sudo systemctl status vault
```

### 3.3 First-time initialization (run once, ever)

```bash
export VAULT_ADDR='http://127.0.0.1:8200'

# Initialize with a single unseal key (simplest for dev/lab)
vault operator init -key-shares=1 -key-threshold=1
```

Output will look like:

```
Unseal Key 1: aBcDeFgHiJkLmNoPqRsTuVwXyZ1234567890abcd=
Initial Root Token: hvs.ABCDEFGHIJKLMNOP
```

**Save both values in a password manager.** You need:
- The **unseal key** every time Vault restarts
- The **root token** to authenticate

Now unseal and authenticate:

```bash
vault operator unseal <paste-unseal-key>
export VAULT_TOKEN='hvs.ABCDEFGHIJKLMNOP'

# Enable the KV v2 secrets engine
vault secrets enable -path=secret kv-v2
```

### 3.4 After a reboot — unseal Vault

Vault starts automatically via systemd but boots in a **sealed** state.
You must unseal it once before it can serve secrets:

```bash
export VAULT_ADDR='http://127.0.0.1:8200'
vault operator unseal <paste-unseal-key>
export VAULT_TOKEN='hvs.ABCDEFGHIJKLMNOP'

# Verify
vault status
vault kv get secret/infra/jumpbox
```

Your secrets are still on disk — you just need to unseal so Vault can
decrypt them.

### 3.5 Optional: unseal helper script

To avoid typing the full unseal flow each time, create `~/bin/vault-unseal`:

```bash
mkdir -p ~/bin
cat > ~/bin/vault-unseal <<'SCRIPT'
#!/bin/bash
export VAULT_ADDR='http://127.0.0.1:8200'
echo "Unsealing Vault..."
echo "Paste your unseal key:"
read -rs UNSEAL_KEY
vault operator unseal "$UNSEAL_KEY"
echo ""
vault status
SCRIPT
chmod +x ~/bin/vault-unseal
```

Usage after reboot: `vault-unseal` — paste your key, done.

## 4. Alternative: Dev Server (ephemeral)

Quick for throwaway testing. All data is in-memory only — lost on restart.

```bash
vault server -dev -dev-root-token-id="dev-root-token"
```

In another terminal:
```bash
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='dev-root-token'
```

## 5. Alternative: Remote/Production Vault

If you have an existing Vault server elsewhere:

```bash
export VAULT_ADDR='https://vault.yourcompany.com:8200'
export VAULT_TOKEN='hvs.your-token-here'
# Or: vault login -method=userpass username=you
```

## 6. Enable KV v2 Secrets Engine (if not already)

If you followed section 3.3, this is already done. Otherwise:

```bash
vault secrets enable -path=secret kv-v2
```

If you get `path is already in use`, the engine is already enabled.

## 7. Seed Host Credentials

Store one secret per host. Required fields: `host`, `user`, `password`.
Optional: `port` (default 22), `shell` (default `bash`).

### Jumpbox
```bash
vault kv put secret/infra/jumpbox \
  host="10.0.0.1" \
  user="jumpuser" \
  password="your-jumpbox-password"
```

### Linux target VM
```bash
vault kv put secret/infra/vm01 \
  host="192.168.122.10" \
  user="admin" \
  password="your-vm-password"
```

### Windows target VM
```bash
vault kv put secret/infra/winvm01 \
  host="192.168.122.20" \
  port="22" \
  user="Administrator" \
  password="your-win-password" \
  shell="powershell"
```

## 8. Verify Setup

```bash
# Check Vault connectivity
vault status

# Verify secrets are readable
vault kv get secret/infra/jumpbox
vault kv get secret/infra/vm01

# Test the skill script (replace with the actual path to your skills directory)
bash ~/.config/opencode/skills/vault-ssh-exec/vault-ssh-exec.sh exec \
  --jump-vault-path secret/infra/jumpbox \
  --target-vault-path secret/infra/vm01 \
  --command "hostname"
```

## 9. Set Environment Variables Permanently

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
export VAULT_ADDR='http://127.0.0.1:8200'
```

For the token, you have two choices:

- **Convenience** (dev/lab only): also add `export VAULT_TOKEN='hvs.xxx'`
  to your profile. Simple but the token is in a plain-text file.
- **Safer**: run `export VAULT_TOKEN='hvs.xxx'` manually each session, or
  use `vault login` interactively.

## Troubleshooting

| Problem | Fix |
|---|---|
| `vault: command not found` | Install Vault CLI (step 1) |
| `sshpass: command not found` | Install sshpass (step 2) or let the script auto-install |
| `VAULT_ADDR is not set` | `export VAULT_ADDR='...'` |
| `VAULT_TOKEN is not set` | `export VAULT_TOKEN='...'` or run `vault login` |
| `Vault is sealed` | Run `vault operator unseal <key>` after server restart |
| `No 'host' field found at Vault path` | Check `vault kv get <path>` has the expected fields |
| `Permission denied` on SSH | Verify password in Vault is correct; ensure `PasswordAuthentication yes` in target's `sshd_config` |
| `Connection refused` | Verify host/port in Vault; ensure jumpbox and target are up |
