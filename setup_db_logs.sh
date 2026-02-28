#!/usr/bin/env bash
set -euo pipefail

# Detect Windows-like environments (Git Bash / MSYS / Cygwin)
OS_TYPE="$(uname -s 2>/dev/null || echo unknown)"
IS_WINDOWS_ENV=false
case "${OS_TYPE}" in
  MINGW*|MSYS*|CYGWIN*)
    IS_WINDOWS_ENV=true
    ;;
esac

# On Linux/macOS root is needed for chown to UID 999; on Windows skip this requirement.
if [[ "${IS_WINDOWS_ENV}" != true && "${EUID}" -ne 0 ]]; then
  echo "Please run this script with sudo (root privileges required)." >&2
  exit 1
fi

# Resolve repository root (directory of this script)
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/db_logs"

mkdir -p "${LOG_DIR}"
chmod -R 755 "${LOG_DIR}"

if [[ "${IS_WINDOWS_ENV}" == true ]]; then
  echo "Windows/MSYS environment detected: skipping chown 999:999"
else
  chown -R 999:999 "${LOG_DIR}"
fi

echo "Log directory prepared at: ${LOG_DIR}"
