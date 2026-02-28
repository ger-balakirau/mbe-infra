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
  -h, --help           Show this help

Notes:
  - Content of storage/ and OperatorWayBill/ is not synchronized.
  - Directories storage/ and OperatorWayBill/ are created on remote if missing.
  - If env file exists, variables DEPLOY_* are used as defaults.
EOF
}

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

REMOTE_HOST="${DEPLOY_REMOTE_HOST:-${REMOTE_HOST}}"
REMOTE_USER="${DEPLOY_REMOTE_USER:-${REMOTE_USER}}"
REMOTE_PORT="${DEPLOY_REMOTE_PORT:-${REMOTE_PORT}}"
REMOTE_PATH="${DEPLOY_REMOTE_PATH:-${REMOTE_PATH}}"
SSH_KEY="${DEPLOY_SSH_KEY:-${SSH_KEY}}"
OWNER="${DEPLOY_OWNER:-${OWNER}}"
GROUP="${DEPLOY_GROUP:-${GROUP}}"
SOURCE_DIR="${DEPLOY_SOURCE_DIR:-${SOURCE_DIR}}"

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
      if [[ ! -f "${ENV_FILE}" ]]; then
        echo "Error: env file does not exist: ${ENV_FILE}" >&2
        exit 1
      fi
      set -a
      # shellcheck disable=SC1090
      source "${ENV_FILE}"
      set +a
      REMOTE_HOST="${DEPLOY_REMOTE_HOST:-${REMOTE_HOST}}"
      REMOTE_USER="${DEPLOY_REMOTE_USER:-${REMOTE_USER}}"
      REMOTE_PORT="${DEPLOY_REMOTE_PORT:-${REMOTE_PORT}}"
      REMOTE_PATH="${DEPLOY_REMOTE_PATH:-${REMOTE_PATH}}"
      SSH_KEY="${DEPLOY_SSH_KEY:-${SSH_KEY}}"
      OWNER="${DEPLOY_OWNER:-${OWNER}}"
      GROUP="${DEPLOY_GROUP:-${GROUP}}"
      SOURCE_DIR="${DEPLOY_SOURCE_DIR:-${SOURCE_DIR}}"
      ;;
    --key) SSH_KEY="${2:-}"; shift 2 ;;
    --owner) OWNER="${2:-}"; shift 2 ;;
    --group) GROUP="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN="1"; shift ;;
    --delete) DELETE_MODE="1"; shift ;;
    --no-perms) APPLY_PERMS="0"; shift ;;
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
  --checksum
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

if [[ "${APPLY_PERMS}" == "1" && "${DRY_RUN}" != "1" ]]; then
  echo "Applying ownership and permissions on remote"
  ssh "${SSH_OPTS[@]}" "${REMOTE_USER}@${REMOTE_HOST}" \
    "TARGET='${REMOTE_PATH}' OWNER='${OWNER}' GROUP='${GROUP}' bash -s" <<'EOF'
set -euo pipefail
mkdir -p "${TARGET}/storage" "${TARGET}/OperatorWayBill"
chown "${OWNER}:${GROUP}" "${TARGET}" "${TARGET}/storage" "${TARGET}/OperatorWayBill"

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

chmod 775 "${TARGET}/storage" "${TARGET}/OperatorWayBill"
EOF
fi

echo "Done"
