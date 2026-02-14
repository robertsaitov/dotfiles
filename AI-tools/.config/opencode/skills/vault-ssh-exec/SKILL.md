---
name: vault-ssh-exec
description: >
  Execute commands or transfer files on remote VMs via SSH with password-based
  authentication. Supports direct connections or routing through a jumpbox.
  Credentials are fetched from HashiCorp Vault at runtime so the LLM never
  sees passwords. Use when user needs to run commands, deploy files, or manage
  remote VMs.
---

## Purpose

Run bash or PowerShell commands and transfer files on a target VM using
password-based SSH authentication. Supports two modes:

- **Direct**: connect straight to the target VM (omit `--jump-vault-path`)
- **Via jumpbox**: tunnel through an SSH jumpbox to reach the target

All credentials are stored in HashiCorp Vault (KV v2) and retrieved by the
bundled script — **you (the agent) never see or handle passwords**.

## Prerequisites

- **Vault CLI** (`vault`) installed and on `PATH`.
- **`sshpass`** installed (script auto-installs if missing).
- Environment variables set by the user:
  - `VAULT_ADDR` — Vault server URL (e.g. `https://vault.example.com:8200`)
  - `VAULT_TOKEN` — valid Vault auth token
- First-time setup: read `{baseDir}/setup-vault.md` and guide the user.

## Vault Secret Structure

Each host has its own Vault KV v2 path with these fields:

| Field      | Required | Default | Description                        |
|------------|----------|---------|------------------------------------|
| `host`     | yes      |         | IP or hostname                     |
| `port`     | no       | `22`    | SSH port                           |
| `user`     | yes      |         | SSH username                       |
| `password` | yes      |         | SSH password                       |
| `shell`    | no       | `bash`  | `bash` or `powershell`             |

Example Vault paths:
```
secret/infra/jumpbox   → { host, user, password }
secret/infra/vm01      → { host, user, password }
secret/infra/winvm01   → { host, user, password, shell: "powershell" }
```

## Usage

### Execute a command — via jumpbox

```bash
bash {baseDir}/vault-ssh-exec.sh exec \
  --jump-vault-path secret/infra/jumpbox \
  --target-vault-path secret/infra/vm01 \
  --command "systemctl status nginx"
```

### Execute a command — direct (no jumpbox)

```bash
bash {baseDir}/vault-ssh-exec.sh exec \
  --target-vault-path secret/infra/vm01 \
  --command "systemctl status nginx"
```

Override shell (e.g. force PowerShell on a Windows target):

```bash
bash {baseDir}/vault-ssh-exec.sh exec \
  --target-vault-path secret/infra/winvm01 \
  --shell powershell \
  --command "Get-Service | Where-Object { \$_.Status -eq 'Running' }"
```

### Upload a file to the target VM

```bash
bash {baseDir}/vault-ssh-exec.sh upload \
  --jump-vault-path secret/infra/jumpbox \
  --target-vault-path secret/infra/vm01 \
  --local /tmp/deploy.tar.gz \
  --remote /opt/app/
```

### Download a file from the target VM

```bash
bash {baseDir}/vault-ssh-exec.sh download \
  --target-vault-path secret/infra/vm01 \
  --remote /var/log/app.log \
  --local /tmp/
```

**Note**: `--jump-vault-path` is optional on all subcommands. Omit it for
direct connections; include it to route through a jumpbox.

## Output Format

The script outputs structured status lines and the full remote command output:

```
[vault-ssh-exec] Connecting to 192.168.1.50:22 via jumpbox 10.0.0.1:22...
[vault-ssh-exec] Shell: bash | Command: systemctl status nginx
--- REMOTE OUTPUT ---
<full stdout and stderr from the remote command>
--- END REMOTE OUTPUT ---
[vault-ssh-exec] Exit code: 0
```

You (the agent) can read and analyze the REMOTE OUTPUT section to debug
issues, check results, and advise the user.

## Rules

1. **NEVER** read Vault secrets directly — never run `vault kv get` or
   `vault read` yourself. Always use the bundled script which fetches
   secrets internally and writes them to temp files (never the environment).
2. **NEVER** log, echo, or display passwords or the `VAULT_TOKEN` value.
3. **NEVER** attempt to extract credentials from the script output.
4. If the script fails with a Vault authentication error, ask the user to
   verify their `VAULT_ADDR` and `VAULT_TOKEN` environment variables.
5. If the script fails with an SSH connection error, report the error
   message and exit code to the user. Suggest they verify:
   - The Vault path and secret fields are correct
   - The jumpbox and target VM are reachable
   - SSH password authentication is enabled on both hosts (`PasswordAuthentication yes` in sshd_config)
6. For **Windows targets**, either set `shell: powershell` in Vault or pass
   `--shell powershell`. Commands are auto-encoded via PowerShell's
   `-EncodedCommand` (base64 UTF-16LE) so special characters are safe.
7. For multi-line commands on Linux, join with `&&` or `;`.
   For multi-line PowerShell, join with `;` or wrap in a script block.
8. Always capture and report the exit code to the user.
9. For **directory transfers**, pass `--recursive` (or the script auto-detects
   directories on upload). Download always requires `--recursive` for dirs.
10. **Security note**: SSH host key checking is disabled for automation.
    This is a trade-off — acceptable for internal/lab networks but means
    MITM attacks are not detected. Inform users if they ask about security.

## Example Workflows

### Debugging a failing service

```
User: "Check why nginx is down on vm01"

1. Run: bash {baseDir}/vault-ssh-exec.sh exec \
     --jump-vault-path secret/infra/jumpbox \
     --target-vault-path secret/infra/vm01 \
     --command "systemctl status nginx; journalctl -u nginx --no-pager -n 50"
2. Read the REMOTE OUTPUT to diagnose the issue.
3. If config is broken, fix it and upload:
   bash {baseDir}/vault-ssh-exec.sh upload \
     --jump-vault-path secret/infra/jumpbox \
     --target-vault-path secret/infra/vm01 \
     --local /tmp/fixed-nginx.conf \
     --remote /etc/nginx/nginx.conf
4. Restart the service:
   bash {baseDir}/vault-ssh-exec.sh exec \
     --jump-vault-path secret/infra/jumpbox \
     --target-vault-path secret/infra/vm01 \
     --command "sudo systemctl restart nginx && systemctl status nginx"
```

### Deploying to a Windows VM

```
User: "Deploy app.zip to the Windows VM and extract it"

1. Upload: bash {baseDir}/vault-ssh-exec.sh upload \
     --jump-vault-path secret/infra/jumpbox \
     --target-vault-path secret/infra/winvm01 \
     --local ./app.zip \
     --remote C:/Temp/
2. Extract: bash {baseDir}/vault-ssh-exec.sh exec \
     --jump-vault-path secret/infra/jumpbox \
     --target-vault-path secret/infra/winvm01 \
     --shell powershell \
     --command "Expand-Archive -Path C:/Temp/app.zip -DestinationPath C:/App -Force"
```
