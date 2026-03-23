#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/lib/common.sh"

SUBSCRIPTIONS=""
SERVICES="virtual-machines,aks,sql,storage,network"
TOP=200
BASELINE_DIR=""

usage() {
  cat <<'EOF'
Usage:
  ./multi-subscription-audit.sh --subscriptions "sub1,sub2,sub3" [--services LIST] [--top N] [--baseline-dir DIR]

Options:
  --subscriptions LIST   Comma-separated Azure subscription IDs (required)
  --services LIST        Services for findings (default: virtual-machines,aks,sql,storage,network)
  --top N                Max usage rows per subscription (default: 200)
  --baseline-dir DIR     Directory containing baseline files named <subscription-id>.json
  -h, --help             Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --subscriptions)
      SUBSCRIPTIONS="${2:-}"
      shift 2
      ;;
    --services)
      SERVICES="${2:-$SERVICES}"
      shift 2
      ;;
    --top)
      TOP="${2:-200}"
      shift 2
      ;;
    --baseline-dir)
      BASELINE_DIR="${2:-}"
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

if [[ -z "$SUBSCRIPTIONS" ]]; then
  log_error "--subscriptions is required"
  usage
  exit 1
fi

require_cmd jq
require_cmd python3
ensure_reports_dir

IFS=',' read -r -a SUB_ARRAY <<< "$SUBSCRIPTIONS"
if [[ "${#SUB_ARRAY[@]}" -eq 0 ]]; then
  log_error "No subscriptions parsed from --subscriptions"
  exit 1
fi

results_tmp="$(mktemp)"
echo "[]" > "$results_tmp"

for sub in "${SUB_ARRAY[@]}"; do
  sub="$(echo "$sub" | xargs)"
  if [[ -z "$sub" ]]; then
    continue
  fi

  log_info "Running live audit for subscription: $sub"
  cmd=( "$SCRIPT_DIR/live-audit.sh" --subscription "$sub" --all --services "$SERVICES" --top "$TOP" )
  if [[ -n "$BASELINE_DIR" && -f "$BASELINE_DIR/$sub.json" ]]; then
    cmd+=( --baseline "$BASELINE_DIR/$sub.json" )
  fi
  "${cmd[@]}" >/dev/null

  latest="$(ls -t "$SCRIPT_DIR"/reports/azure-live-cost-audit-*.json 2>/dev/null | head -n 1 || true)"
  if [[ -z "$latest" || ! -f "$latest" ]]; then
    log_warn "No JSON report found after running subscription $sub"
    continue
  fi

  jq --arg sub "$sub" --arg file "$latest" '
    . + [{
      subscription_id: $sub,
      report_file: $file,
      finding_count: (.summary.finding_count // 0),
      savings_low: (.summary.savings_low // 0),
      savings_high: (.summary.savings_high // 0),
      high_severity_count: ((.findings // []) | map(select(.severity == "high")) | length)
    }]' "$latest" | jq -s '.[0] + .[1]' "$results_tmp" - > "${results_tmp}.new"
  mv "${results_tmp}.new" "$results_tmp"
done

summary_base="$(report_file_base "azure-multi-subscription-summary")"
summary_json="${summary_base}.json"
summary_txt="${summary_base}.txt"

jq -n --arg date "$(today_utc)" --arg ts "$(timestamp_utc)" --slurpfile rows "$results_tmp" '
  {
    audit_date: $date,
    timestamp: $ts,
    mode: "multi-subscription-live",
    subscription_count: ($rows[0] | length),
    totals: {
      findings: (($rows[0] | map(.finding_count) | add) // 0),
      savings_low: (($rows[0] | map(.savings_low) | add) // 0),
      savings_high: (($rows[0] | map(.savings_high) | add) // 0),
      high_severity_count: (($rows[0] | map(.high_severity_count) | add) // 0)
    },
    subscriptions: ($rows[0] // [])
  }' > "$summary_json"

{
  echo "Azure Multi-Subscription Audit Summary"
  echo "Audit date (UTC): $(today_utc)"
  echo "Subscriptions analyzed: $(jq '.subscription_count' "$summary_json")"
  echo "Total findings: $(jq '.totals.findings' "$summary_json")"
  echo "Total savings/month: $(jq '.totals.savings_low' "$summary_json") - $(jq '.totals.savings_high' "$summary_json")"
  echo "Total high severity findings: $(jq '.totals.high_severity_count' "$summary_json")"
  echo
  echo "Summary JSON: $summary_json"
} > "$summary_txt"

rm -f "$results_tmp"
log_info "Text summary: $summary_txt"
log_info "JSON summary: $summary_json"
echo "Done."
