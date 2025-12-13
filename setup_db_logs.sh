#!/usr/bin/env bash
set -euo pipefail

# Ensure the script is executed with root privileges (e.g., via sudo)
if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run this script with sudo (root privileges required)." >&2
  exit 1
fi

# Resolve repository root (directory of this script)
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/db_logs"

mkdir -p "${LOG_DIR}"
chown -R 999:999 "${LOG_DIR}"
chmod -R 755 "${LOG_DIR}"

echo "Log directory prepared at: ${LOG_DIR}"
