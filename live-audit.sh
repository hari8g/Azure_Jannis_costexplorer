#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/lib/common.sh"

SUBSCRIPTION_ID=""
RUN_ALL=0
TOP=200
SERVICES="virtual-machines,aks,sql,storage,network"
BASELINE_FILE=""

usage() {
  cat <<'EOF'
Usage:
  ./live-audit.sh --subscription <subscription-id> [--all] [--services LIST] [--top N] [--baseline FILE]

Options:
  --subscription ID   Azure subscription ID (required)
  --all               Run all default live checks
  --services LIST     Comma-separated services (virtual-machines,aks,sql,storage,network)
  --top N             Max usage rows to query (default: 200)
  --baseline FILE     Baseline JSON report for new/fixed diff
  -h, --help          Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --subscription)
      SUBSCRIPTION_ID="${2:-}"
      shift 2
      ;;
    --all)
      RUN_ALL=1
      shift
      ;;
    --services)
      SERVICES="${2:-$SERVICES}"
      shift 2
      ;;
    --top)
      TOP="${2:-200}"
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

if [[ -z "$SUBSCRIPTION_ID" ]]; then
  log_error "--subscription is required"
  usage
  exit 1
fi

require_cmd az
require_cmd jq
require_cmd python3
ensure_reports_dir

if [[ "$RUN_ALL" -eq 0 ]]; then
  log_warn "No section flags provided; defaulting to --all behavior."
  RUN_ALL=1
fi

log_info "Setting Azure subscription context..."
az account set --subscription "$SUBSCRIPTION_ID"

base="$(report_file_base "azure-live-cost-audit")"
json_file="${base}.json"
txt_file="${base}.txt"

log_info "Collecting subscription metadata..."
sub_json="$(az account show -o json)"

log_info "Collecting consumption usage (top=${TOP})..."
usage_json="$(az consumption usage list --top "$TOP" -o json 2>/dev/null || echo "[]")"

log_info "Collecting Azure Advisor cost recommendations..."
advisor_json="$(az advisor recommendation list --category Cost -o json 2>/dev/null || echo "[]")"

usage_tmp="$(mktemp)"
advisor_tmp="$(mktemp)"
sub_tmp="$(mktemp)"
printf '%s' "$usage_json" > "$usage_tmp"
printf '%s' "$advisor_json" > "$advisor_tmp"
printf '%s' "$sub_json" > "$sub_tmp"

python3 "$SCRIPT_DIR/scripts/generate_live_findings.py" \
  --subscription-json "$sub_tmp" \
  --usage-json "$usage_tmp" \
  --advisor-json "$advisor_tmp" \
  --services "$SERVICES" \
  --out "$json_file"

rm -f "$usage_tmp" "$advisor_tmp" "$sub_tmp"

if [[ -n "$BASELINE_FILE" ]]; then
  log_info "Applying baseline diff..."
  apply_baseline_diff "$json_file" "$BASELINE_FILE"
fi

usage_count="$(jq '.service_costs | to_entries | map(.value) | add // 0' "$json_file" 2>/dev/null || echo 0)"
advisor_count="$(jq '.findings | map(select(.id | test("advisor"))) | length' "$json_file" 2>/dev/null || echo 0)"
finding_count="$(jq '.summary.finding_count // 0' "$json_file" 2>/dev/null || echo 0)"

{
  echo "Azure Live Cost Audit"
  echo "Audit date (UTC): $(today_utc)"
  echo "Timestamp (UTC): $(timestamp_utc)"
  echo "Subscription: $(jq -r '.name // "unknown"' <<<"$sub_json") ($(jq -r '.id // "unknown"' <<<"$sub_json"))"
  echo
  echo "Summary"
  echo "- Selected services: $SERVICES"
  echo "- Findings: $finding_count"
  echo "- Advisor-derived findings: $advisor_count"
  echo "- Observed monthly service spend (selected): $usage_count"
  if [[ -n "$BASELINE_FILE" ]]; then
    echo "- Baseline file: $BASELINE_FILE"
    echo "- New findings: $(jq '.baseline_diff.new | length // 0' "$json_file" 2>/dev/null || echo 0)"
    echo "- Fixed findings: $(jq '.baseline_diff.fixed | length // 0' "$json_file" 2>/dev/null || echo 0)"
  fi
  echo
  echo "JSON report: $json_file"
} > "$txt_file"

log_info "Text report: $txt_file"
log_info "JSON report: $json_file"
echo "Done."
