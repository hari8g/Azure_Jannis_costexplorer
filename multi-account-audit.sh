#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  ./multi-account-audit.sh --profiles sub1,sub2 [--services LIST] [--baseline-dir DIR]

Notes:
- Azure equivalent maps AWS "profiles/accounts" to Azure subscriptions.
EOF
}

PROFILES=""
SERVICES="virtual-machines,aks,sql,storage,network"
BASELINE_DIR=""
TOP=200

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profiles) PROFILES="${2:-}"; shift 2 ;;
    --services) SERVICES="${2:-$SERVICES}"; shift 2 ;;
    --baseline-dir|--output-dir|--regions|--region|--edition)
      if [[ "$1" == "--baseline-dir" ]]; then BASELINE_DIR="${2:-}"; fi
      shift 2
      ;;
    --top) TOP="${2:-200}"; shift 2 ;;
    --parallel|--no-cross-account-analysis|--org-sp|--)
      shift
      ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$PROFILES" ]] || { echo "--profiles is required" >&2; exit 1; }

"$SCRIPT_DIR/multi-subscription-audit.sh" \
  --subscriptions "$PROFILES" \
  --services "$SERVICES" \
  --top "$TOP" \
  ${BASELINE_DIR:+--baseline-dir "$BASELINE_DIR"}
