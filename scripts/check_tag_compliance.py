#!/usr/bin/env python3
import argparse
import json
from datetime import datetime, timezone


def parse_required_tags(raw):
    return [t.strip() for t in raw.split(",") if t.strip()]


def main():
    parser = argparse.ArgumentParser(description="Check required tags on Azure resources")
    parser.add_argument("--resources-json", required=True, help="Path to JSON from az resource list")
    parser.add_argument("--required-tags", default="owner,costCenter,environment")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    required = parse_required_tags(args.required_tags)
    with open(args.resources_json, "r", encoding="utf-8") as f:
        resources = json.load(f)

    total = len(resources)
    compliant = 0
    missing_details = []

    for r in resources:
        tags = r.get("tags") or {}
        missing = [t for t in required if t not in tags or str(tags.get(t, "")).strip() == ""]
        if missing:
            missing_details.append(
                {
                    "resource_id": r.get("id", "unknown"),
                    "name": r.get("name", "unknown"),
                    "type": r.get("type", "unknown"),
                    "missing_tags": missing,
                }
            )
        else:
            compliant += 1

    non_compliant = total - compliant
    compliance_pct = 100.0 if total == 0 else round((compliant / total) * 100.0, 2)

    result = {
        "timestamp_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "required_tags": required,
        "summary": {
            "total_resources": total,
            "compliant_resources": compliant,
            "non_compliant_resources": non_compliant,
            "compliance_percentage": compliance_pct,
        },
        "non_compliant": missing_details,
        "status": "pass" if non_compliant == 0 else "fail",
    }

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2)

    print(args.out)


if __name__ == "__main__":
    main()
