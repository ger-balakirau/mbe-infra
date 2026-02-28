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
  bash scripts/deploy/push-crm.sh --host <host> [options]

Options:
  --host <host>        Remote host or IP (required)
  --user <user>        SSH user (default: root)
  --port <port>        SSH port (default: 22)
  --path <path>        Remote CRM path (default: /var/www/html/mbelab.com/crm)
  --source <path>      Local CRM source path
  --env-file <path>    Path to deploy env file (default: .env.deploy in infra root)
  --key <path>         SSH private key
  --owner <owner>      Ownership user on remote (default: www-data)
  --group <group>      Ownership group on remote (default: www-data)
  --dry-run            Show changes without writing
  --delete             Delete remote files that are missing locally
  --no-perms           Skip remote chmod/chown step
  --full-perms         Force full chmod/chown scan over project (slow)
  --no-opcache-reload  Skip OPCache/app service reload after deploy
  -h, --help           Show this help

Notes:
  - Content of storage/ and OperatorWayBill/ is not synchronized.
  - Directories storage/ and OperatorWayBill/ are created on remote if missing.
  - If env file exists, variables DEPLOY_* are used as defaults.
  - By default, ownership/perms are applied only to changed files via rsync.
EOF
}

if [[ -f "${ENV_FILE}" ]]; then
  load_env_file "${ENV_FILE}"
fi

apply_env_defaults

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) REMOTE_HOST="${2:-}"; shift 2 ;;
    --user) REMOTE_USER="${2:-}"; shift 2 ;;
    --port) REMOTE_PORT="${2:-}"; shift 2 ;;
    --path) REMOTE_PATH="${2:-}"; shift 2 ;;
    --source) SOURCE_DIR="${2:-}"; shift 2 ;;
    --env-file)
      ENV_FILE="${2:-}"
      shift 2
      load_env_file "${ENV_FILE}"
      ;;
    --key) SSH_KEY="${2:-}"; shift 2 ;;
    --owner) OWNER="${2:-}"; shift 2 ;;
    --group) GROUP="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN="1"; shift ;;
    --delete) DELETE_MODE="1"; shift ;;
    --no-perms) APPLY_PERMS="0"; shift ;;
    --full-perms) FULL_PERMS="1"; shift ;;
    --no-opcache-reload) RELOAD_OPCACHE="0"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "${REMOTE_HOST}" ]]; then
  echo "Error: --host is required" >&2
  usage
  exit 1
fi

if [[ ! -d "${SOURCE_DIR}" ]]; then
  echo "Error: source path does not exist: ${SOURCE_DIR}" >&2
  exit 1
fi

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
  --exclude='/storage/**'
  --exclude='/OperatorWayBill/**'
)

if [[ "${APPLY_PERMS}" == "1" ]]; then
  RSYNC_OPTS+=(
    "--chown=${OWNER}:${GROUP}"
    --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r
  )
fi

if [[ "${DELETE_MODE}" == "1" ]]; then
  RSYNC_OPTS+=(--delete)
fi

if [[ "${DRY_RUN}" == "1" ]]; then
  RSYNC_OPTS+=(--dry-run --itemize-changes)
  echo "Dry run mode enabled"
fi

if [[ "${DRY_RUN}" != "1" ]]; then
  echo "Preparing remote directories on ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"
  ssh "${SSH_OPTS[@]}" "${REMOTE_USER}@${REMOTE_HOST}" \
    "mkdir -p '${REMOTE_PATH}' '${REMOTE_PATH}/storage' '${REMOTE_PATH}/OperatorWayBill'"
else
  echo "Dry run: remote directory creation skipped"
fi

echo "Syncing ${SOURCE_DIR} -> ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"
rsync "${RSYNC_OPTS[@]}" -e "ssh ${SSH_OPTS[*]}" \
  "${SOURCE_DIR}/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/"

if [[ "${APPLY_PERMS}" == "1" && "${FULL_PERMS}" == "1" && "${DRY_RUN}" != "1" ]]; then
  echo "Running full ownership/permissions scan on remote (slow)"
  ssh "${SSH_OPTS[@]}" "${REMOTE_USER}@${REMOTE_HOST}" \
    "TARGET='${REMOTE_PATH}' OWNER='${OWNER}' GROUP='${GROUP}' bash -s" <<'EOF'
set -euo pipefail
mkdir -p "${TARGET}/storage" "${TARGET}/OperatorWayBill"
chown "${OWNER}:${GROUP}" "${TARGET}" "${TARGET}/storage" "${TARGET}/OperatorWayBill" || true

find "${TARGET}" \
  \( -path "${TARGET}/storage" -o -path "${TARGET}/storage/*" -o \
     -path "${TARGET}/OperatorWayBill" -o -path "${TARGET}/OperatorWayBill/*" \) \
  -prune -o -exec chown "${OWNER}:${GROUP}" {} +

find "${TARGET}" \
  \( -path "${TARGET}/storage" -o -path "${TARGET}/storage/*" -o \
     -path "${TARGET}/OperatorWayBill" -o -path "${TARGET}/OperatorWayBill/*" \) \
  -prune -o -type d -exec chmod 755 {} +

find "${TARGET}" \
  \( -path "${TARGET}/storage" -o -path "${TARGET}/storage/*" -o \
     -path "${TARGET}/OperatorWayBill" -o -path "${TARGET}/OperatorWayBill/*" \) \
  -prune -o -type f -exec chmod 644 {} +

# Runtime directories are managed outside deploy sync.
chmod 775 "${TARGET}/storage" "${TARGET}/OperatorWayBill" || true
EOF
fi

if [[ "${RELOAD_OPCACHE}" == "1" && "${DRY_RUN}" != "1" ]]; then
  echo "Reloading PHP/Apache services to refresh OPCache"
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

for svc in php7.0-fpm php7.1-fpm php7.2-fpm php7.3-fpm php7.4-fpm php8.0-fpm php8.1-fpm php8.2-fpm php8.3-fpm apache2; do
  if reload_service "${svc}"; then
    echo "Reloaded ${svc}"
    reloaded=1
  fi
done

if [[ "${reloaded}" != "1" ]]; then
  echo "Warning: no known php-fpm/apache service found to reload" >&2
fi
EOF
fi

echo "Done"
