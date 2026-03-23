#!/usr/bin/env python3
import argparse
import json
import sys


def main():
    parser = argparse.ArgumentParser(description="Policy gate for Azure FinOps reports")
    parser.add_argument("--report", required=True, help="Path to JSON report")
    parser.add_argument("--max-high-severity", type=int, default=0, help="Allowed high severity findings")
    parser.add_argument("--max-findings", type=int, default=99999, help="Allowed total findings")
    args = parser.parse_args()

    with open(args.report, "r", encoding="utf-8") as f:
        report = json.load(f)

    findings = report.get("findings", [])
    high_count = len([f for f in findings if f.get("severity") == "high"])
    total = report.get("summary", {}).get("finding_count", len(findings))

    print(f"Policy gate input: {args.report}")
    print(f"Total findings: {total}")
    print(f"High severity findings: {high_count}")

    failed = False
    if high_count > args.max_high_severity:
        print(f"FAIL: high severity findings ({high_count}) exceeds max ({args.max_high_severity})")
        failed = True
    if total > args.max_findings:
        print(f"FAIL: total findings ({total}) exceeds max ({args.max_findings})")
        failed = True

    if failed:
        sys.exit(1)
    print("PASS: policy gate checks passed")


if __name__ == "__main__":
    main()
