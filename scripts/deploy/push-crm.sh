#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SOURCE_DIR="${PROJECT_ROOT}/html/mbelab.com/crm"
ENV_FILE="${PROJECT_ROOT}/.env.deploy"

REMOTE_HOST=""
REMOTE_USER="root"
REMOTE_PORT="22"
REMOTE_PATH="/var/www/html/mbelab.com/crm"
SSH_KEY=""
OWNER="www-data"
GROUP="www-data"
DRY_RUN="0"
DELETE_MODE="0"
APPLY_PERMS="1"
RELOAD_OPCACHE="1"
FULL_PERMS="0"
INCLUDE_CONFIG_INC="0"
ENV_FILE_EXPLICIT="0"

require_option_value() {
  local opt="$1"
  local value="${2:-}"
  if [[ -z "${value}" ]]; then
    echo "Error: ${opt} requires a value" >&2
    exit 1
  fi
}

apply_env_defaults() {
  REMOTE_HOST="${DEPLOY_REMOTE_HOST:-${REMOTE_HOST}}"
  REMOTE_USER="${DEPLOY_REMOTE_USER:-${REMOTE_USER}}"
  REMOTE_PORT="${DEPLOY_REMOTE_PORT:-${REMOTE_PORT}}"
  REMOTE_PATH="${DEPLOY_REMOTE_PATH:-${REMOTE_PATH}}"
  SSH_KEY="${DEPLOY_SSH_KEY:-${SSH_KEY}}"
  OWNER="${DEPLOY_OWNER:-${OWNER}}"
  GROUP="${DEPLOY_GROUP:-${GROUP}}"
  SOURCE_DIR="${DEPLOY_SOURCE_DIR:-${SOURCE_DIR}}"
  RELOAD_OPCACHE="${DEPLOY_RELOAD_OPCACHE:-${RELOAD_OPCACHE}}"
  FULL_PERMS="${DEPLOY_FULL_PERMS:-${FULL_PERMS}}"
  INCLUDE_CONFIG_INC="${DEPLOY_INCLUDE_CONFIG_INC:-${INCLUDE_CONFIG_INC}}"
}

load_env_file() {
  local file="$1"
  if [[ ! -f "${file}" ]]; then
    echo "Error: env file does not exist: ${file}" >&2
    exit 1
  fi
  set -a
  # shellcheck disable=SC1090
  source "${file}"
  set +a
  apply_env_defaults
}

usage() {
  cat <<'EOF'
Usage:
  bash scripts/deploy/push-crm.sh [--host <host>] [options]

Options:
  --host <host>        Remote host or IP (or DEPLOY_REMOTE_HOST from env file)
  --user <user>        SSH user (default: root)
  --port <port>        SSH port (default: 22)
  --path <path>        Remote CRM path (default: /var/www/html/mbelab.com/crm)
  --source <path>      Local CRM source path
  --env-file <path>    Path to deploy env file (default: .env.deploy if exists)
  --key <path>         SSH private key
  --owner <owner>      Ownership user on remote (default: www-data)
  --group <group>      Ownership group on remote (default: www-data)
  --dry-run            Show changes without writing (requires existing remote runtime layout)
  --delete             Delete remote files that are missing locally
  --no-perms           Skip remote chmod/chown step
  --full-perms         Force full chmod/chown scan over project (slow)
  --with-config-inc    Include config.inc.php in sync (disabled by default)
  --no-opcache-reload  Skip OPCache/app service reload after deploy
  -h, --help           Show this help

Notes:
  - Legacy deploy target: Debian Stretch + PHP 7.x + Apache 2.
  - Runtime/generated paths are NOT synchronized by default:
    storage/, OperatorWayBill/, cache/, user_privileges/, kcfinder/upload/, cron/output.txt
  - Local secret files are NOT synchronized by default:
    .mbe, config.csrf-secret.php, config_override.php, config.inc.php
  - config.inc.php can be enabled explicitly with --with-config-inc.
  - Runtime dirs/files are created on remote in normal mode (non --dry-run).
  - In --dry-run mode script only verifies remote runtime layout and fails if missing.
  - If env file exists, variables DEPLOY_* are used as defaults.
  - CLI options always override env defaults, regardless of argument order.
  - By default, ownership/perms are applied only to changed files via rsync.
EOF
}

ARGS=("$@")
scan_idx=0
while [[ ${scan_idx} -lt ${#ARGS[@]} ]]; do
  case "${ARGS[$scan_idx]}" in
    --host|--user|--port|--path|--source|--key|--owner|--group)
      next_idx=$((scan_idx + 1))
      require_option_value "${ARGS[$scan_idx]}" "${ARGS[$next_idx]:-}"
      scan_idx=$((scan_idx + 2))
      ;;
    --env-file)
      next_idx=$((scan_idx + 1))
      require_option_value "--env-file" "${ARGS[$next_idx]:-}"
      ENV_FILE="${ARGS[$next_idx]}"
      ENV_FILE_EXPLICIT="1"
      scan_idx=$((scan_idx + 2))
      ;;
    --dry-run|--delete|--no-perms|--full-perms|--with-config-inc|--no-opcache-reload|-h|--help)
      scan_idx=$((scan_idx + 1))
      ;;
    *)
      scan_idx=$((scan_idx + 1))
      ;;
  esac
done

if [[ "${ENV_FILE_EXPLICIT}" == "1" ]]; then
  load_env_file "${ENV_FILE}"
elif [[ -f "${ENV_FILE}" ]]; then
  load_env_file "${ENV_FILE}"
else
  apply_env_defaults
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) require_option_value "$1" "${2:-}"; REMOTE_HOST="${2:-}"; shift 2 ;;
    --user) require_option_value "$1" "${2:-}"; REMOTE_USER="${2:-}"; shift 2 ;;
    --port) require_option_value "$1" "${2:-}"; REMOTE_PORT="${2:-}"; shift 2 ;;
    --path) require_option_value "$1" "${2:-}"; REMOTE_PATH="${2:-}"; shift 2 ;;
    --source) require_option_value "$1" "${2:-}"; SOURCE_DIR="${2:-}"; shift 2 ;;
    --env-file)
      require_option_value "$1" "${2:-}"
      ENV_FILE="${2:-}"
      shift 2
      ;;
    --key) require_option_value "$1" "${2:-}"; SSH_KEY="${2:-}"; shift 2 ;;
    --owner) require_option_value "$1" "${2:-}"; OWNER="${2:-}"; shift 2 ;;
    --group) require_option_value "$1" "${2:-}"; GROUP="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN="1"; shift ;;
    --delete) DELETE_MODE="1"; shift ;;
    --no-perms) APPLY_PERMS="0"; shift ;;
    --full-perms) FULL_PERMS="1"; shift ;;
    --with-config-inc) INCLUDE_CONFIG_INC="1"; shift ;;
    --no-opcache-reload) RELOAD_OPCACHE="0"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "${REMOTE_HOST}" ]]; then
  echo "Error: remote host is empty (set --host or DEPLOY_REMOTE_HOST)" >&2
  usage
  exit 1
fi

if [[ ! -d "${SOURCE_DIR}" ]]; then
  echo "Error: source path does not exist: ${SOURCE_DIR}" >&2
  exit 1
fi

prepare_remote_runtime_layout() {
  # shellcheck disable=SC2029
  ssh "${SSH_OPTS[@]}" "${REMOTE_USER}@${REMOTE_HOST}" \
    "TARGET='${REMOTE_PATH}' OWNER='${OWNER}' GROUP='${GROUP}' APPLY_PERMS='${APPLY_PERMS}' bash -s" <<'EOF'
set -euo pipefail

mkdir -p \
  "${TARGET}" \
  "${TARGET}/storage" \
  "${TARGET}/OperatorWayBill" \
  "${TARGET}/cache" \
  "${TARGET}/user_privileges" \
  "${TARGET}/kcfinder" \
  "${TARGET}/kcfinder/upload" \
  "${TARGET}/cron"

[[ -f "${TARGET}/user_privileges/index.html" ]] || printf '%s\n' '<html><body></body></html>' > "${TARGET}/user_privileges/index.html"
[[ -f "${TARGET}/user_privileges/audit_trail.php" ]] || printf '%s\n' '<?php' > "${TARGET}/user_privileges/audit_trail.php"
[[ -f "${TARGET}/user_privileges/default_module_view.php" ]] || printf '%s\n' '<?php' > "${TARGET}/user_privileges/default_module_view.php"
[[ -f "${TARGET}/user_privileges/enable_backup.php" ]] || printf '%s\n' '<?php' > "${TARGET}/user_privileges/enable_backup.php"
[[ -f "${TARGET}/cron/output.txt" ]] || : > "${TARGET}/cron/output.txt"

if [[ "${APPLY_PERMS}" == "1" ]]; then
  chown "${OWNER}:${GROUP}" \
    "${TARGET}" \
    "${TARGET}/storage" \
    "${TARGET}/OperatorWayBill" \
    "${TARGET}/cache" \
    "${TARGET}/user_privileges" \
    "${TARGET}/kcfinder" \
    "${TARGET}/kcfinder/upload" \
    "${TARGET}/cron" \
    "${TARGET}/user_privileges/index.html" \
    "${TARGET}/user_privileges/audit_trail.php" \
    "${TARGET}/user_privileges/default_module_view.php" \
    "${TARGET}/user_privileges/enable_backup.php" \
    "${TARGET}/cron/output.txt" || true

  chmod 755 "${TARGET}" "${TARGET}/kcfinder" || true
  chmod 775 \
    "${TARGET}/storage" \
    "${TARGET}/OperatorWayBill" \
    "${TARGET}/cache" \
    "${TARGET}/user_privileges" \
    "${TARGET}/kcfinder/upload" \
    "${TARGET}/cron" || true
  chmod 664 \
    "${TARGET}/user_privileges/index.html" \
    "${TARGET}/user_privileges/audit_trail.php" \
    "${TARGET}/user_privileges/default_module_view.php" \
    "${TARGET}/user_privileges/enable_backup.php" \
    "${TARGET}/cron/output.txt" || true
fi
EOF
}

check_remote_runtime_layout() {
  local missing
  missing="$(
    # shellcheck disable=SC2029
    ssh "${SSH_OPTS[@]}" "${REMOTE_USER}@${REMOTE_HOST}" \
      "TARGET='${REMOTE_PATH}' bash -s" <<'EOF'
set -euo pipefail

missing=()

for dir in \
  "${TARGET}" \
  "${TARGET}/storage" \
  "${TARGET}/OperatorWayBill" \
  "${TARGET}/cache" \
  "${TARGET}/user_privileges" \
  "${TARGET}/kcfinder" \
  "${TARGET}/kcfinder/upload" \
  "${TARGET}/cron"
do
  [[ -d "${dir}" ]] || missing+=("${dir}")
done

for file in \
  "${TARGET}/user_privileges/index.html" \
  "${TARGET}/user_privileges/audit_trail.php" \
  "${TARGET}/user_privileges/default_module_view.php" \
  "${TARGET}/user_privileges/enable_backup.php" \
  "${TARGET}/cron/output.txt"
do
  [[ -f "${file}" ]] || missing+=("${file}")
done

if [[ "${#missing[@]}" -gt 0 ]]; then
  printf '%s\n' "${missing[@]}"
fi
EOF
  )"

  if [[ -n "${missing}" ]]; then
    echo "Error: missing remote runtime paths for dry-run:" >&2
    while IFS= read -r path; do
      [[ -z "${path}" ]] && continue
      echo "  - ${path}" >&2
    done <<< "${missing}"
    echo "Run deploy once without --dry-run to create missing runtime dirs/files." >&2
    exit 1
  fi
}

SSH_OPTS=(-p "${REMOTE_PORT}")
if [[ -n "${SSH_KEY}" ]]; then
  SSH_OPTS+=(-i "${SSH_KEY}")
fi

RSYNC_OPTS=(
  -az
  --omit-dir-times
  --no-perms
  --no-owner
  --no-group
  --exclude='.git/'
  --exclude='.gitignore'
  --exclude='.git-ftp.log'
  --exclude='/.mbe'
  --exclude='/config.csrf-secret.php'
  --exclude='/config_override.php'
  --exclude='/storage/***'
  --exclude='/OperatorWayBill/***'
  --exclude='/cache/***'
  --exclude='/user_privileges/***'
  --exclude='/kcfinder/upload/***'
  --exclude='/cron/output.txt'
)

if [[ "${INCLUDE_CONFIG_INC}" != "1" ]]; then
  RSYNC_OPTS+=(--exclude='/config.inc.php')
fi

if [[ "${APPLY_PERMS}" == "1" ]]; then
  RSYNC_OPTS+=(
    "--chown=${OWNER}:${GROUP}"
    "--chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r"
  )
fi

if [[ "${DELETE_MODE}" == "1" ]]; then
  RSYNC_OPTS+=(--delete)
fi

if [[ "${DRY_RUN}" == "1" ]]; then
  RSYNC_OPTS+=(--dry-run --itemize-changes)
  echo "Dry run mode enabled"
fi

if [[ "${DRY_RUN}" == "1" ]]; then
  echo "Checking remote runtime layout on ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"
  check_remote_runtime_layout
else
  echo "Preparing remote runtime layout on ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"
  prepare_remote_runtime_layout
fi

echo "Syncing ${SOURCE_DIR} -> ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"
rsync "${RSYNC_OPTS[@]}" -e "ssh ${SSH_OPTS[*]}" \
  "${SOURCE_DIR}/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/"

if [[ "${APPLY_PERMS}" == "1" && "${FULL_PERMS}" == "1" && "${DRY_RUN}" != "1" ]]; then
  echo "Running full ownership/permissions scan on remote (slow)"
  # shellcheck disable=SC2029
  ssh "${SSH_OPTS[@]}" "${REMOTE_USER}@${REMOTE_HOST}" \
    "TARGET='${REMOTE_PATH}' OWNER='${OWNER}' GROUP='${GROUP}' bash -s" <<'EOF'
set -euo pipefail
mkdir -p "${TARGET}/storage" "${TARGET}/OperatorWayBill" "${TARGET}/cache" "${TARGET}/user_privileges" "${TARGET}/kcfinder/upload" "${TARGET}/cron"
chown "${OWNER}:${GROUP}" \
  "${TARGET}" \
  "${TARGET}/storage" \
  "${TARGET}/OperatorWayBill" \
  "${TARGET}/cache" \
  "${TARGET}/user_privileges" \
  "${TARGET}/kcfinder/upload" \
  "${TARGET}/cron" || true

find "${TARGET}" \
  \( -path "${TARGET}/storage" -o -path "${TARGET}/storage/*" -o \
     -path "${TARGET}/OperatorWayBill" -o -path "${TARGET}/OperatorWayBill/*" -o \
     -path "${TARGET}/cache" -o -path "${TARGET}/cache/*" -o \
     -path "${TARGET}/user_privileges" -o -path "${TARGET}/user_privileges/*" -o \
     -path "${TARGET}/kcfinder/upload" -o -path "${TARGET}/kcfinder/upload/*" -o \
     -path "${TARGET}/cron" -o -path "${TARGET}/cron/*" \) \
  -prune -o -exec chown "${OWNER}:${GROUP}" {} +

find "${TARGET}" \
  \( -path "${TARGET}/storage" -o -path "${TARGET}/storage/*" -o \
     -path "${TARGET}/OperatorWayBill" -o -path "${TARGET}/OperatorWayBill/*" -o \
     -path "${TARGET}/cache" -o -path "${TARGET}/cache/*" -o \
     -path "${TARGET}/user_privileges" -o -path "${TARGET}/user_privileges/*" -o \
     -path "${TARGET}/kcfinder/upload" -o -path "${TARGET}/kcfinder/upload/*" -o \
     -path "${TARGET}/cron" -o -path "${TARGET}/cron/*" \) \
  -prune -o -type d -exec chmod 755 {} +

find "${TARGET}" \
  \( -path "${TARGET}/storage" -o -path "${TARGET}/storage/*" -o \
     -path "${TARGET}/OperatorWayBill" -o -path "${TARGET}/OperatorWayBill/*" -o \
     -path "${TARGET}/cache" -o -path "${TARGET}/cache/*" -o \
     -path "${TARGET}/user_privileges" -o -path "${TARGET}/user_privileges/*" -o \
     -path "${TARGET}/kcfinder/upload" -o -path "${TARGET}/kcfinder/upload/*" -o \
     -path "${TARGET}/cron" -o -path "${TARGET}/cron/*" \) \
  -prune -o -type f -exec chmod 644 {} +

# Runtime directories are managed outside deploy sync.
chmod 775 \
  "${TARGET}/storage" \
  "${TARGET}/OperatorWayBill" \
  "${TARGET}/cache" \
  "${TARGET}/user_privileges" \
  "${TARGET}/kcfinder/upload" \
  "${TARGET}/cron" || true
EOF
fi

if [[ "${RELOAD_OPCACHE}" == "1" && "${DRY_RUN}" != "1" ]]; then
  echo "Reloading legacy PHP 7/Apache services to refresh OPCache"
  ssh "${SSH_OPTS[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "bash -s" <<'EOF'
set -euo pipefail
reloaded=0

reload_service() {
  local svc="$1"
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep -qx "${svc}.service"; then
      systemctl reload "${svc}" 2>/dev/null || systemctl restart "${svc}" 2>/dev/null
      return 0
    fi
  fi
  if command -v service >/dev/null 2>&1; then
    if service "${svc}" status >/dev/null 2>&1; then
      service "${svc}" reload >/dev/null 2>&1 || service "${svc}" restart >/dev/null 2>&1
      return 0
    fi
  fi
  return 1
}

for svc in php7.0-fpm php7.1-fpm php7.2-fpm php7.3-fpm php7.4-fpm php-fpm apache2 httpd; do
  if reload_service "${svc}"; then
    echo "Reloaded ${svc}"
    reloaded=1
  fi
done

if [[ "${reloaded}" != "1" ]]; then
  echo "Warning: no known PHP 7/Apache service found to reload" >&2
fi
EOF
fi

echo "Done"
