#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/lib/common.sh"

CSV_PATH=""
SERVICES="virtual-machines,aks,sql,storage,network"
BASELINE_FILE=""

usage() {
  cat <<'EOF'
Usage:
  ./export-audit.sh --csv /path/to/azure-cost-export.csv [--services LIST] [--baseline FILE]

Options:
  --csv PATH     Azure Cost Management export CSV (required)
  --services     Comma-separated services (virtual-machines,aks,sql,storage,network)
  --baseline     Baseline JSON report for new/fixed diff
  -h, --help     Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --csv)
      CSV_PATH="${2:-}"
      shift 2
      ;;
    --services)
      SERVICES="${2:-$SERVICES}"
      shift 2
      ;;
    --baseline)
      BASELINE_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$CSV_PATH" ]]; then
  log_error "--csv is required"
  usage
  exit 1
fi

if [[ ! -f "$CSV_PATH" ]]; then
  log_error "CSV file not found: $CSV_PATH"
  exit 1
fi

require_cmd python3
ensure_reports_dir

base="$(report_file_base "azure-export-cost-audit")"
json_file="${base}.json"
txt_file="${base}.txt"

log_info "Summarizing Azure export CSV..."
python3 "$SCRIPT_DIR/scripts/generate_export_findings.py" \
  --csv "$CSV_PATH" \
  --services "$SERVICES" \
  --out "$json_file"

if [[ -n "$BASELINE_FILE" ]]; then
  log_info "Applying baseline diff..."
  apply_baseline_diff "$json_file" "$BASELINE_FILE"
fi

{
  echo "Azure Export Cost Audit"
  echo "Audit date (UTC): $(today_utc)"
  echo "Input CSV: $CSV_PATH"
  echo "JSON summary: $json_file"
  echo "Selected services: $SERVICES"
  echo
  echo "Findings: $(jq '.summary.finding_count // 0' "$json_file" 2>/dev/null || echo 0)"
  echo "Savings/month: $(jq '.summary.savings_low // 0' "$json_file" 2>/dev/null || echo 0) - $(jq '.summary.savings_high // 0' "$json_file" 2>/dev/null || echo 0)"
  if [[ -n "$BASELINE_FILE" ]]; then
    echo "New findings: $(jq '.baseline_diff.new | length // 0' "$json_file" 2>/dev/null || echo 0)"
    echo "Fixed findings: $(jq '.baseline_diff.fixed | length // 0' "$json_file" 2>/dev/null || echo 0)"
  fi
  echo
  echo "Top 10 resource groups by cost:"
  jq -r '.top_resource_groups[] | "- \(.resource_group): \(.cost)"' "$json_file" 2>/dev/null || true
} > "$txt_file"

log_info "Text report: $txt_file"
log_info "JSON report: $json_file"
echo "Done."
