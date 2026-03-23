#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  ./cur-audit.sh <csv-file...> [--all | --services LIST] [--dashboard] [--profile NAME] [--baseline FILE]

Notes:
- Azure equivalent of AWS CUR runner.
- Multiple CSV files are supported; files with matching headers are merged.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

declare -a CSV_FILES=()
SERVICES="virtual-machines,aks,sql,storage,network"
DASHBOARD=0
BASELINE=""
PROFILE_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      shift
      ;;
    --services)
      SERVICES="${2:-$SERVICES}"
      shift 2
      ;;
    --dashboard)
      DASHBOARD=1
      shift
      ;;
    --profile)
      PROFILE_NAME="${2:-}"
      shift 2
      ;;
    --baseline)
      BASELINE="${2:-}"
      shift 2
      ;;
    --days|--scan-max-rows|--company|--title|--output|--output-file|--output-dir|--webhook|--debug|--bench|--skip-summary)
      # accepted for CLI compatibility; currently no-op in Azure wrapper
      if [[ "${2:-}" =~ ^--|^$ ]]; then shift; else shift 2; fi
      ;;
    --*)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [[ ! -f "$1" ]]; then
        echo "File not found: $1" >&2
        exit 1
      fi
      CSV_FILES+=("$1")
      shift
      ;;
  esac
done

if [[ "${#CSV_FILES[@]}" -eq 0 ]]; then
  echo "At least one CSV file is required." >&2
  usage
  exit 1
fi

if [[ -n "$PROFILE_NAME" ]]; then
  az account set --subscription "$PROFILE_NAME" >/dev/null 2>&1 || true
fi

CSV_INPUT=""
if [[ "${#CSV_FILES[@]}" -eq 1 ]]; then
  CSV_INPUT="${CSV_FILES[0]}"
else
  CSV_INPUT="$(mktemp)"
  python3 - "$CSV_INPUT" "${CSV_FILES[@]}" <<'PY'
import csv, sys
out = sys.argv[1]
files = sys.argv[2:]
header = None
with open(out, "w", newline="", encoding="utf-8") as wf:
    writer = None
    for i, path in enumerate(files):
        with open(path, newline="", encoding="utf-8-sig") as rf:
            r = csv.DictReader(rf)
            if r.fieldnames is None:
                continue
            if header is None:
                header = r.fieldnames
                writer = csv.DictWriter(wf, fieldnames=header)
                writer.writeheader()
            for row in r:
                # write only known fields for compatibility
                writer.writerow({k: row.get(k, "") for k in header})
PY
fi

cmd=( "$SCRIPT_DIR/export-audit.sh" --csv "$CSV_INPUT" --services "$SERVICES" )
if [[ -n "$BASELINE" ]]; then
  cmd+=( --baseline "$BASELINE" )
fi
"${cmd[@]}"

if [[ "$DASHBOARD" -eq 1 ]]; then
  "$SCRIPT_DIR/dashboard/dashboard-gen.sh" --reports "$SCRIPT_DIR/reports" --out "$SCRIPT_DIR/reports/dashboard.html" >/dev/null
fi

if [[ "${#CSV_FILES[@]}" -gt 1 ]]; then
  rm -f "$CSV_INPUT"
fi

echo "Done."
