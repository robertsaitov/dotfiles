#!/usr/bin/env bash
# vault-ssh-exec.sh — Execute commands or transfer files on a remote VM,
# optionally via SSH jumpbox. Credentials fetched from HashiCorp Vault.
#
# Security design:
#   - Passwords written to temp files (mode 0600), used via sshpass -f
#   - ProxyCommand uses a temp wrapper script to avoid quote-injection
#   - No passwords in CLI args, env exports, or log output
#   - Cleanup trap removes all temp files on exit/interrupt
#   - Tracing (set -x) disabled around sensitive sections
set -euo pipefail

###############################################################################
# Constants
###############################################################################
SCRIPT_NAME="vault-ssh-exec"
SSH_OPTS=(
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o ConnectTimeout=10
  -o ServerAliveInterval=30
  -o LogLevel=ERROR
  -o PreferredAuthentications=password
)
TEMP_FILES=()
USE_JUMPBOX="no"

###############################################################################
# Helpers
###############################################################################
log()   { echo "[${SCRIPT_NAME}] $*"; }
err()   { echo "[${SCRIPT_NAME}] ERROR: $*" >&2; }
die()   { err "$@"; exit 1; }

cleanup() {
  [[ ${#TEMP_FILES[@]} -eq 0 ]] && return
  for f in "${TEMP_FILES[@]}"; do
    [[ -f "$f" ]] && rm -f "$f"
  done
}
trap cleanup EXIT INT TERM

# Create a temp file, register it for cleanup, return its path.
make_temp() {
  local f
  f=$(mktemp "${TMPDIR:-/tmp}/vault-ssh-exec.XXXXXXXXXX")
  chmod 0600 "$f"
  TEMP_FILES+=("$f")
  echo "$f"
}

usage() {
  cat <<'USAGE'
Usage:
  vault-ssh-exec.sh exec     --target-vault-path PATH [--jump-vault-path PATH] --command "CMD" [--shell bash|powershell]
  vault-ssh-exec.sh upload   --target-vault-path PATH [--jump-vault-path PATH] --local FILE --remote PATH [--recursive]
  vault-ssh-exec.sh download --target-vault-path PATH [--jump-vault-path PATH] --remote FILE --local PATH [--recursive]

Options:
  --target-vault-path  Vault KV v2 path for target VM creds (e.g. secret/infra/vm01)   [required]
  --jump-vault-path    Vault KV v2 path for jumpbox creds   (e.g. secret/infra/jumpbox) [optional]
  --command            Command to execute on target VM
  --shell              Override shell: bash (default) or powershell
  --local              Local file/directory path (for upload/download)
  --remote             Remote file/directory path (for upload/download)
  --recursive          Recursive copy for directories (upload/download)

If --jump-vault-path is omitted, the script connects directly to the target.

Environment:
  VAULT_ADDR           Vault server address  (required)
  VAULT_TOKEN          Vault auth token      (required)
USAGE
  exit 1
}

###############################################################################
# Prerequisite checks
###############################################################################
check_prereqs() {
  # Vault CLI
  if ! command -v vault &>/dev/null; then
    die "vault CLI not found. See setup-vault.md for installation instructions."
  fi

  # sshpass — auto-install if missing
  if ! command -v sshpass &>/dev/null; then
    log "sshpass not found. Attempting auto-install..."
    if command -v apt-get &>/dev/null; then
      sudo apt-get update -qq && sudo apt-get install -y -qq sshpass
    elif command -v dnf &>/dev/null; then
      sudo dnf install -y -q sshpass
    elif command -v yum &>/dev/null; then
      sudo yum install -y -q sshpass
    elif command -v brew &>/dev/null; then
      brew install hudochenkov/sshpass/sshpass
    elif command -v pacman &>/dev/null; then
      sudo pacman -S --noconfirm sshpass
    else
      die "Cannot auto-install sshpass. Install it manually: https://github.com/kevinburke/sshpass"
    fi
    command -v sshpass &>/dev/null || die "sshpass installation failed."
    log "sshpass installed successfully."
  fi

  # Vault env vars
  [[ -n "${VAULT_ADDR:-}" ]]  || die "VAULT_ADDR is not set. Export it: export VAULT_ADDR='https://vault.example.com:8200'"
  [[ -n "${VAULT_TOKEN:-}" ]] || die "VAULT_TOKEN is not set. Export it: export VAULT_TOKEN='hvs.xxxxx'"
}

###############################################################################
# Input validation
###############################################################################
# Validate that a Vault-sourced value is safe for use in shell commands.
# Allows: alphanumeric, dots, hyphens, underscores, and (for user) backslash.
validate_ssh_field() {
  local name="$1" value="$2" pattern="$3"
  if [[ ! "$value" =~ $pattern ]]; then
    die "Invalid ${name}: '${value}' — contains disallowed characters"
  fi
}

###############################################################################
# Vault secret retrieval
###############################################################################
vault_get_field() {
  local path="$1" field="$2" required="${3:-yes}"
  local val="" vault_rc=0

  local vault_stderr
  vault_stderr=$(make_temp)

  val=$(vault kv get -field="$field" "$path" 2>"$vault_stderr") || vault_rc=$?

  if [[ $vault_rc -ne 0 ]]; then
    local errmsg
    errmsg=$(<"$vault_stderr")
    # Distinguish "field not found" from real errors
    if echo "$errmsg" | grep -qi "no value found\|field.*not present"; then
      if [[ "$required" == "yes" ]]; then
        die "Required field '${field}' not found at Vault path: ${path}"
      fi
      echo ""
      return 0
    fi
    die "Vault error reading ${path}/${field} (exit ${vault_rc}): ${errmsg}"
  fi

  echo "$val"
}

# Load credentials for a host into local variables. Writes password to a temp
# file and returns the file path — never exports passwords to the environment.
#
# Sets global variables: {PREFIX}_HOST, {PREFIX}_PORT, {PREFIX}_USER,
# {PREFIX}_PASSFILE, {PREFIX}_SHELL
load_host_creds() {
  local path="$1" prefix="$2"

  # Save and disable tracing to prevent password leaks via bash -x
  local _prev_flags="$-"
  { set +x; } 2>/dev/null

  local host port user password shell_type passfile

  host=$(vault_get_field "$path" "host" "yes")
  port=$(vault_get_field "$path" "port" "no")
  port="${port:-22}"
  user=$(vault_get_field "$path" "user" "yes")
  password=$(vault_get_field "$path" "password" "yes")
  shell_type=$(vault_get_field "$path" "shell" "no")
  shell_type="${shell_type:-bash}"

  # Validate fields that will be interpolated into shell commands.
  # This prevents injection via malicious Vault values.
  validate_ssh_field "host"  "$host" '^[a-zA-Z0-9._-]+$'
  validate_ssh_field "port"  "$port" '^[0-9]+$'
  validate_ssh_field "user"  "$user" '^[a-zA-Z0-9._@\\-]+$'
  validate_ssh_field "shell" "$shell_type" '^(bash|powershell)$'

  # Write password to a temp file (mode 0600) for sshpass -f
  passfile=$(make_temp)
  printf '%s' "$password" > "$passfile"
  # Clear password from memory as best we can in bash
  password=""

  # Set script-global variables (not exported to child processes).
  # These are consumed by do_exec/do_upload/do_download in the same process.
  printf -v "${prefix}_HOST"     '%s' "$host"
  printf -v "${prefix}_PORT"     '%s' "$port"
  printf -v "${prefix}_USER"     '%s' "$user"
  printf -v "${prefix}_PASSFILE" '%s' "$passfile"
  printf -v "${prefix}_SHELL"    '%s' "$shell_type"

  # Restore previous shell flags
  if [[ "$_prev_flags" == *x* ]]; then set -x; fi
}

###############################################################################
# SSH proxy command builder
###############################################################################
# Creates a wrapper script for ProxyCommand that reads the jumpbox password
# from a file. This avoids embedding passwords in command strings (no
# quote-injection risk).
build_proxy_script() {
  local script_file
  script_file=$(make_temp)
  cat > "$script_file" <<PROXY_SCRIPT
#!/bin/sh
exec sshpass -f '${JUMP_PASSFILE}' ssh \\
  -o StrictHostKeyChecking=no \\
  -o UserKnownHostsFile=/dev/null \\
  -o ConnectTimeout=10 \\
  -o LogLevel=ERROR \\
  -o PreferredAuthentications=password \\
  -p '${JUMP_PORT}' \\
  -W %h:%p \\
  '${JUMP_USER}@${JUMP_HOST}'
PROXY_SCRIPT
  chmod 0700 "$script_file"
  echo "$script_file"
}

###############################################################################
# Subcommand: exec
###############################################################################
do_exec() {
  local command="$1"
  local shell_override="${2:-}"
  local shell_type="${shell_override:-$TARGET_SHELL}"

  if [[ "$USE_JUMPBOX" == "yes" ]]; then
    log "Connecting to ${TARGET_HOST}:${TARGET_PORT} via jumpbox ${JUMP_HOST}:${JUMP_PORT}..."
  else
    log "Connecting directly to ${TARGET_HOST}:${TARGET_PORT}..."
  fi
  log "Shell: ${shell_type} | Command: ${command}"

  # Wrap command for powershell targets using -EncodedCommand for safe quoting
  local remote_cmd="$command"
  if [[ "$shell_type" == "powershell" ]]; then
    local encoded
    encoded=$(printf '%s' "$command" | iconv -t UTF-16LE | base64 -w 0)
    remote_cmd="powershell.exe -NoProfile -NonInteractive -EncodedCommand ${encoded}"
  fi

  local -a proxy_opts=()
  if [[ "$USE_JUMPBOX" == "yes" ]]; then
    local proxy_script
    proxy_script=$(build_proxy_script)
    proxy_opts+=(-o "ProxyCommand=${proxy_script}")
  fi

  echo "--- REMOTE OUTPUT ---"
  local rc=0
  sshpass -f "${TARGET_PASSFILE}" ssh \
    "${SSH_OPTS[@]}" \
    "${proxy_opts[@]+"${proxy_opts[@]}"}" \
    -p "${TARGET_PORT}" \
    "${TARGET_USER}@${TARGET_HOST}" \
    "${remote_cmd}" || rc=$?
  echo "--- END REMOTE OUTPUT ---"
  log "Exit code: ${rc}"
  return $rc
}

###############################################################################
# Subcommand: upload
###############################################################################
do_upload() {
  local local_path="$1" remote_path="$2" recursive="$3"

  [[ -e "$local_path" ]] || die "Local path does not exist: $local_path"

  log "Uploading ${local_path} -> ${TARGET_USER}@${TARGET_HOST}:${remote_path}"
  if [[ "$USE_JUMPBOX" == "yes" ]]; then
    log "Via jumpbox ${JUMP_HOST}:${JUMP_PORT}..."
  fi

  local -a proxy_opts=()
  if [[ "$USE_JUMPBOX" == "yes" ]]; then
    local proxy_script
    proxy_script=$(build_proxy_script)
    proxy_opts+=(-o "ProxyCommand=${proxy_script}")
  fi

  local -a scp_extra=()
  if [[ "$recursive" == "yes" ]] || [[ -d "$local_path" ]]; then
    scp_extra+=(-r)
  fi

  local rc=0
  sshpass -f "${TARGET_PASSFILE}" scp \
    "${SSH_OPTS[@]}" \
    "${scp_extra[@]+"${scp_extra[@]}"}" \
    "${proxy_opts[@]+"${proxy_opts[@]}"}" \
    -P "${TARGET_PORT}" \
    "${local_path}" \
    "${TARGET_USER}@${TARGET_HOST}:${remote_path}" || rc=$?

  if [[ $rc -eq 0 ]]; then
    log "Upload complete."
  else
    err "Upload failed with exit code: ${rc}"
  fi
  return $rc
}

###############################################################################
# Subcommand: download
###############################################################################
do_download() {
  local remote_path="$1" local_path="$2" recursive="$3"

  log "Downloading ${TARGET_USER}@${TARGET_HOST}:${remote_path} -> ${local_path}"
  if [[ "$USE_JUMPBOX" == "yes" ]]; then
    log "Via jumpbox ${JUMP_HOST}:${JUMP_PORT}..."
  fi

  local -a proxy_opts=()
  if [[ "$USE_JUMPBOX" == "yes" ]]; then
    local proxy_script
    proxy_script=$(build_proxy_script)
    proxy_opts+=(-o "ProxyCommand=${proxy_script}")
  fi

  local -a scp_extra=()
  if [[ "$recursive" == "yes" ]]; then
    scp_extra+=(-r)
  fi

  local rc=0
  sshpass -f "${TARGET_PASSFILE}" scp \
    "${SSH_OPTS[@]}" \
    "${scp_extra[@]+"${scp_extra[@]}"}" \
    "${proxy_opts[@]+"${proxy_opts[@]}"}" \
    -P "${TARGET_PORT}" \
    "${TARGET_USER}@${TARGET_HOST}:${remote_path}" \
    "${local_path}" || rc=$?

  if [[ $rc -eq 0 ]]; then
    log "Download complete."
  else
    err "Download failed with exit code: ${rc}"
  fi
  return $rc
}

###############################################################################
# Argument parsing
###############################################################################
main() {
  [[ $# -ge 1 ]] || usage

  local subcommand="$1"; shift
  local jump_vault_path="" target_vault_path="" command="" shell_override=""
  local local_path="" remote_path="" recursive="no"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --jump-vault-path)
        [[ $# -ge 2 ]] || die "--jump-vault-path requires a value"
        jump_vault_path="$2"; shift 2 ;;
      --target-vault-path)
        [[ $# -ge 2 ]] || die "--target-vault-path requires a value"
        target_vault_path="$2"; shift 2 ;;
      --command)
        [[ $# -ge 2 ]] || die "--command requires a value"
        command="$2"; shift 2 ;;
      --shell)
        [[ $# -ge 2 ]] || die "--shell requires a value"
        [[ "$2" == "bash" || "$2" == "powershell" ]] || die "--shell must be 'bash' or 'powershell', got: $2"
        shell_override="$2"; shift 2 ;;
      --local)
        [[ $# -ge 2 ]] || die "--local requires a value"
        local_path="$2"; shift 2 ;;
      --remote)
        [[ $# -ge 2 ]] || die "--remote requires a value"
        remote_path="$2"; shift 2 ;;
      --recursive|-r)
        recursive="yes"; shift ;;
      -h|--help)
        usage ;;
      *)
        die "Unknown option: $1" ;;
    esac
  done

  # Validate required args
  [[ -n "$target_vault_path" ]] || die "Missing --target-vault-path"

  # Check prerequisites
  check_prereqs

  # Load credentials from Vault (passwords go to temp files, never env/log)
  log "Fetching credentials from Vault..."
  if [[ -n "$jump_vault_path" ]]; then
    USE_JUMPBOX="yes"
    load_host_creds "$jump_vault_path" "JUMP"
  fi
  load_host_creds "$target_vault_path" "TARGET"
  log "Credentials loaded."

  case "$subcommand" in
    exec)
      [[ -n "$command" ]] || die "Missing --command for exec subcommand"
      do_exec "$command" "$shell_override"
      ;;
    upload)
      [[ -n "$local_path" ]]  || die "Missing --local for upload subcommand"
      [[ -n "$remote_path" ]] || die "Missing --remote for upload subcommand"
      do_upload "$local_path" "$remote_path" "$recursive"
      ;;
    download)
      [[ -n "$remote_path" ]] || die "Missing --remote for download subcommand"
      [[ -n "$local_path" ]]  || die "Missing --local for download subcommand"
      do_download "$remote_path" "$local_path" "$recursive"
      ;;
    *)
      die "Unknown subcommand: $subcommand (expected: exec, upload, download)"
      ;;
  esac
}

main "$@"
