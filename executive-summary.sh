#!/usr/bin/env bash
set -euo pipefail

FORMAT="md"
BUDGET=0
OUT_FILE=""
INPUTS=()

usage() {
  cat <<'EOF'
Usage:
  ./executive-summary.sh report1.json report2.json [--output text|md|json]
  ./executive-summary.sh --dir ./reports --budget 500
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      d="${2:-}"
      [[ -d "$d" ]] || { echo "Directory not found: $d" >&2; exit 1; }
      while IFS= read -r f; do INPUTS+=("$f"); done < <(rg --files "$d" -g "*.json")
      shift 2
      ;;
    --output) FORMAT="${2:-md}"; shift 2 ;;
    --budget) BUDGET="${2:-0}"; shift 2 ;;
    --output-file) OUT_FILE="${2:-}"; shift 2 ;;
    --revenue|--tag-attribution-file|--unit-economics-file|--cost-projection-file|--output-dir)
      if [[ "${2:-}" =~ ^--|^$ ]]; then shift; else shift 2; fi
      ;;
    --help|-h) usage; exit 0 ;;
    *)
      [[ -f "$1" ]] || { echo "File not found: $1" >&2; exit 1; }
      INPUTS+=("$1"); shift ;;
  esac
done

[[ "${#INPUTS[@]}" -gt 0 ]] || { echo "No input reports provided." >&2; exit 1; }

tmp="$(mktemp)"
python3 - "$tmp" "$BUDGET" "${INPUTS[@]}" <<'PY'
import json,sys
out=sys.argv[1]; budget=float(sys.argv[2]); files=sys.argv[3:]
findings=[]; services={}
for f in files:
    try: d=json.load(open(f,encoding="utf-8"))
    except Exception: continue
    svc=d.get("mode",d.get("source","unknown"))
    services[svc]=services.get(svc,0)+1
    for x in d.get("findings",[]):
        findings.append(x)
low=sum(float(x.get("savings_low",0) or 0) for x in findings)
high=sum(float(x.get("savings_high",0) or 0) for x in findings)
big=[x for x in findings if float(x.get("savings_high",0) or 0)>=budget]
summary={"report_count":len(files),"finding_count":len(findings),"savings_low":round(low,2),"savings_high":round(high,2),"high_impact_count":len(big),"services":services}
json.dump({"summary":summary,"top_high_impact":big[:15]},open(out,"w",encoding="utf-8"),indent=2)
PY

render_md() {
  jq -r '
    "# Azure Executive Summary",
    "",
    "- Reports analyzed: \(.summary.report_count)",
    "- Findings: \(.summary.finding_count)",
    "- Savings/month: \(.summary.savings_low) - \(.summary.savings_high)",
    "- High-impact findings: \(.summary.high_impact_count)",
    "",
    "## Top High-Impact Findings",
    (.top_high_impact[]? | "- [\(.severity // "unknown")] \(.id // "unknown"): \(.message // "") (\(.savings_high // 0))")
  ' "$tmp"
}

render_text() { render_md; }

case "$FORMAT" in
  json) out_content="$(cat "$tmp")" ;;
  text) out_content="$(render_text)" ;;
  md) out_content="$(render_md)" ;;
  *) echo "Invalid --output format: $FORMAT" >&2; rm -f "$tmp"; exit 1 ;;
esac

if [[ -n "$OUT_FILE" ]]; then
  printf "%s\n" "$out_content" > "$OUT_FILE"
else
  printf "%s\n" "$out_content"
fi
rm -f "$tmp"
