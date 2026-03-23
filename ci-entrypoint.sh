#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  ./ci-entrypoint.sh --mode live --subscription SUB_ID [--services LIST] [--baseline FILE]
  ./ci-entrypoint.sh --mode cur --csv FILE [--services LIST] [--baseline FILE]
  ./ci-entrypoint.sh --diff-summary REPORT1 REPORT2
EOF
}

diff_summary() {
  local r1="$1" r2="$2"
  jq -n --slurpfile a "$r1" --slurpfile b "$r2" '
    {
      report_a_findings: ($a[0].summary.finding_count // 0),
      report_b_findings: ($b[0].summary.finding_count // 0),
      findings_delta: (($a[0].summary.finding_count // 0) - ($b[0].summary.finding_count // 0)),
      savings_high_delta: (($a[0].summary.savings_high // 0) - ($b[0].summary.savings_high // 0))
    }'
}

if [[ "${1:-}" == "--diff-summary" ]]; then
  [[ $# -eq 3 ]] || { usage; exit 1; }
  diff_summary "$2" "$3"
  exit 0
fi

MODE="" SUB="" CSV="" SERVICES="virtual-machines,aks,sql,storage,network" BASELINE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:-}"; shift 2 ;;
    --subscription|--region|--edition) SUB="${2:-}"; shift 2 ;;
    --csv) CSV="${2:-}"; shift 2 ;;
    --services) SERVICES="${2:-$SERVICES}"; shift 2 ;;
    --baseline) BASELINE="${2:-}"; shift 2 ;;
    --output|--webhook|--debug|--sections|--skip|--days|--cluster|--athena-db|--athena-table)
      if [[ "${2:-}" =~ ^--|^$ ]]; then shift; else shift 2; fi
      ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$MODE" ]] || { echo "--mode is required" >&2; exit 1; }

case "$MODE" in
  live)
    [[ -n "$SUB" ]] || { echo "subscription is required for live mode" >&2; exit 1; }
    cmd=( "$SCRIPT_DIR/live-audit.sh" --subscription "$SUB" --all --services "$SERVICES" )
    [[ -n "$BASELINE" ]] && cmd+=( --baseline "$BASELINE" )
    "${cmd[@]}"
    ;;
  cur)
    [[ -n "$CSV" ]] || { echo "--csv is required for cur mode" >&2; exit 1; }
    cmd=( "$SCRIPT_DIR/cur-audit.sh" "$CSV" --services "$SERVICES" )
    [[ -n "$BASELINE" ]] && cmd+=( --baseline "$BASELINE" )
    "${cmd[@]}"
    ;;
  *)
    echo "Invalid mode: $MODE" >&2
    exit 1
    ;;
esac
