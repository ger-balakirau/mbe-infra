#!/usr/bin/env bash
set -euo pipefail

RC_FILE="${1:-}"

if [[ -z "$RC_FILE" ]]; then
  case "${SHELL##*/}" in
    zsh) RC_FILE="$HOME/.zshrc" ;;
    bash|*) RC_FILE="$HOME/.bashrc" ;;
  esac
fi

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "WARNING: running as root. Shell config will be installed for root user."
fi

if [[ "$RC_FILE" == /root/* ]] && [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "ERROR: no permission to write $RC_FILE. Run with sudo/root."
  exit 1
fi

mkdir -p "$(dirname "$RC_FILE")"
touch "$RC_FILE"

START_MARKER="# >>> MBE shell tools >>>"
END_MARKER="# <<< MBE shell tools <<<"

read -r -d '' BLOCK <<'EOF' || true
# >>> MBE shell tools >>>
mbe-root() {
  local dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/docker-compose.yml" ] && [ -f "$dir/Dockerfile" ] && [ -d "$dir/prod.conf" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

mbe() {
  local root
  root="$(mbe-root)" || {
    echo "MBE root not found. Run command from project dir/subdir."
    return 1
  }
  docker compose -f "$root/docker-compose.yml" --project-directory "$root" "$@"
}

mbe-env() {
  local root
  local line key value
  root="$(mbe-root)" || {
    echo "MBE root not found. Run command from project dir/subdir."
    return 1
  }
  if [ ! -f "$root/.env" ]; then
    echo ".env not found at $root/.env"
    return 1
  fi

  # Safe .env loader: parse KEY=VALUE lines only, without executing code.
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"

    case "$line" in
      "" | \#*) continue ;;
      export\ *) line="${line#export }" ;;
    esac

    case "$line" in
      *=*) ;;
      *) continue ;;
    esac

    key="${line%%=*}"
    value="${line#*=}"

    key="${key//[[:space:]]/}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    case "$key" in
      "" | [0-9]* | *[!A-Za-z0-9_]*)
        echo "mbe-env: skip invalid key: $key" >&2
        continue
        ;;
    esac

    case "$value" in
      \"*\") value="${value#\"}"; value="${value%\"}" ;;
      \'*\') value="${value#\'}"; value="${value%\'}" ;;
    esac

    export "$key=$value"
  done < "$root/.env"
}
# <<< MBE shell tools <<<
EOF

if grep -qF "$START_MARKER" "$RC_FILE"; then
  awk -v s="$START_MARKER" -v e="$END_MARKER" '
    BEGIN {skip=0}
    $0==s {skip=1; next}
    $0==e {skip=0; next}
    skip==0 {print}
  ' "$RC_FILE" > "$RC_FILE.tmp"
  mv "$RC_FILE.tmp" "$RC_FILE"
fi

{
  echo
  echo "$BLOCK"
} >> "$RC_FILE"

echo "Installed MBE shell tools into: $RC_FILE"
echo "Reload shell: source \"$RC_FILE\""
