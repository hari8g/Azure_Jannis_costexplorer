#!/usr/bin/env python3
import argparse
import json
from datetime import datetime, timezone


def load_json(path):
    if not path:
        return None
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def main():
    parser = argparse.ArgumentParser(description="Build alert payload from FinOps checks")
    parser.add_argument("--report", required=True)
    parser.add_argument("--anomaly", default="")
    parser.add_argument("--tag-compliance", default="")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    report = load_json(args.report) or {}
    anomaly = load_json(args.anomaly) if args.anomaly else None
    tags = load_json(args.tag_compliance) if args.tag_compliance else None

    findings = int(report.get("summary", {}).get("finding_count", 0) or 0)
    savings_low = float(report.get("summary", {}).get("savings_low", 0) or 0)
    savings_high = float(report.get("summary", {}).get("savings_high", 0) or 0)
    high_count = len([f for f in report.get("findings", []) if f.get("severity") == "high"])

    status = "ok"
    reasons = []
    if high_count > 0:
        status = "warn"
        reasons.append("high_severity_findings")
    if anomaly and anomaly.get("anomaly_detected"):
        status = "critical"
        reasons.append("anomaly_detected")
    if tags and tags.get("status") == "fail":
        status = "warn" if status == "ok" else status
        reasons.append("tag_non_compliance")

    payload = {
        "timestamp_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "status": status,
        "reasons": reasons,
        "summary": {
            "finding_count": findings,
            "high_severity_count": high_count,
            "savings_low": round(savings_low, 2),
            "savings_high": round(savings_high, 2),
        },
        "anomaly": anomaly,
        "tag_compliance": tags,
        "report_file": args.report,
    }

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)
    print(args.out)


if __name__ == "__main__":
    main()
