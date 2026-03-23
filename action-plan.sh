#!/usr/bin/env bash
set -euo pipefail

OUTPUT="text"
OUTPUT_FILE=""
TOP_N=""
INPUTS=()

usage() {
  cat <<'EOF'
Usage:
  ./action-plan.sh report1.json report2.json ...
  ./action-plan.sh --dir ./reports --output json --top 10
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
    --output)
      OUTPUT="${2:-text}"
      shift 2
      ;;
    --output-file)
      OUTPUT_FILE="${2:-}"
      shift 2
      ;;
    --top)
      TOP_N="${2:-}"
      shift 2
      ;;
    --timeframe|--currency|--exchange-rate|--slack-webhook|--debug|--output-dir)
      if [[ "${2:-}" =~ ^--|^$ ]]; then shift; else shift 2; fi
      ;;
    --help|-h)
      usage; exit 0 ;;
    *)
      [[ -f "$1" ]] || { echo "File not found: $1" >&2; exit 1; }
      INPUTS+=("$1")
      shift
      ;;
  esac
done

[[ "${#INPUTS[@]}" -gt 0 ]] || { echo "No input reports provided." >&2; exit 2; }

tmp="$(mktemp)"
python3 - "$tmp" "$TOP_N" "${INPUTS[@]}" <<'PY'
import json,sys
out=sys.argv[1]; top=sys.argv[2]
files=sys.argv[3:]
rows=[]
sev_score={"critical":4,"high":3,"medium":2,"low":1,"info":0}
effort_score={"quick-win":3,"medium":2,"project":1}
for f in files:
    try:
        d=json.load(open(f,encoding="utf-8"))
    except Exception:
        continue
    for x in d.get("findings",[]):
        low=float(x.get("savings_low",0) or 0)
        high=float(x.get("savings_high",0) or 0)
        sev=str(x.get("severity","low")).lower()
        eff=str(x.get("effort","medium")).lower()
        score=((low+high)/2.0)*(sev_score.get(sev,1))*effort_score.get(eff,2)
        rows.append({
            "id": x.get("id","unknown"),
            "service": x.get("service","unknown"),
            "severity": sev,
            "effort": eff,
            "message": x.get("message",""),
            "savings_low": low,
            "savings_high": high,
            "priority_score": round(score,2)
        })
rows.sort(key=lambda r:r["priority_score"], reverse=True)
if top and top.isdigit():
    rows=rows[:int(top)]
summary={
 "action_count": len(rows),
 "savings_low": round(sum(r["savings_low"] for r in rows),2),
 "savings_high": round(sum(r["savings_high"] for r in rows),2),
}
json.dump({"summary":summary,"actions":rows},open(out,"w",encoding="utf-8"),indent=2)
PY

if [[ "$OUTPUT" == "json" ]]; then
  if [[ -n "$OUTPUT_FILE" ]]; then cp "$tmp" "$OUTPUT_FILE"; else cat "$tmp"; fi
else
  text="$(jq -r '
    "Azure Action Plan",
    "Actions: \(.summary.action_count)",
    "Savings/month: \(.summary.savings_low) - \(.summary.savings_high)",
    "",
    (.actions[] | "- [\(.severity)] \(.service) \(.id): \(.message) (\(.savings_low)-\(.savings_high))")
  ' "$tmp")"
  if [[ -n "$OUTPUT_FILE" ]]; then printf "%s\n" "$text" > "$OUTPUT_FILE"; else printf "%s\n" "$text"; fi
fi
rm -f "$tmp"
