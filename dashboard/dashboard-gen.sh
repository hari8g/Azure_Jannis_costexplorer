#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

REPORT_DIR="$ROOT_DIR/reports"
OUT_FILE="$ROOT_DIR/reports/dashboard.html"
TITLE="Azure FinOps Dashboard"

usage() {
  cat <<'EOF'
Usage:
  ./dashboard/dashboard-gen.sh [--reports DIR] [--out FILE] [--title TITLE]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reports)
      REPORT_DIR="${2:-$REPORT_DIR}"
      shift 2
      ;;
    --out)
      OUT_FILE="${2:-$OUT_FILE}"
      shift 2
      ;;
    --title)
      TITLE="${2:-$TITLE}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

python3 "$SCRIPT_DIR/dashboard-gen.py" --reports "$REPORT_DIR" --out "$OUT_FILE" --title "$TITLE"
echo "Dashboard generated: $OUT_FILE"
