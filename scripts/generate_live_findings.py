#!/usr/bin/env python3
import argparse
import json
from collections import defaultdict
from datetime import datetime, timezone

SERVICE_MAP = {
    "vm": "virtual-machines",
    "virtual-machines": "virtual-machines",
    "aks": "aks",
    "sql": "sql",
    "storage": "storage",
    "network": "network",
}

KEYWORDS = {
    "virtual-machines": ["microsoft.compute", "virtualmachines", "vm"],
    "aks": ["microsoft.containerservice", "aks", "kubernetes"],
    "sql": ["microsoft.sql", "postgresql", "mysql", "sql"],
    "storage": ["microsoft.storage", "storage", "blob"],
    "network": ["microsoft.network", "bandwidth", "network", "egress"],
}


def norm_service_name(s: str) -> str:
    return SERVICE_MAP.get((s or "").strip().lower(), "")


def detect_service(text: str) -> str:
    t = (text or "").lower()
    for service, words in KEYWORDS.items():
        if any(w in t for w in words):
            return service
    return "network"


def severity_from_monthly(cost: float) -> str:
    if cost >= 1000:
        return "high"
    if cost >= 250:
        return "medium"
    return "low"


def resource_identifier(item: dict) -> str:
    parts = [
        item.get("instanceName"),
        item.get("resourceGroup"),
        item.get("resourceLocation"),
        item.get("meterId"),
        item.get("meterName"),
    ]
    val = "|".join([(p or "").strip() for p in parts if (p or "").strip()])
    return val or "unknown"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--subscription-json", required=True)
    parser.add_argument("--usage-json", required=True)
    parser.add_argument("--advisor-json", required=True)
    parser.add_argument("--services", default="virtual-machines,aks,sql,storage,network")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    selected = [norm_service_name(s) for s in args.services.split(",")]
    selected = [s for s in selected if s]
    selected_set = set(selected or list(KEYWORDS.keys()))

    with open(args.subscription_json, "r", encoding="utf-8") as f:
        subscription = json.load(f)
    with open(args.usage_json, "r", encoding="utf-8") as f:
        usage = json.load(f)
    with open(args.advisor_json, "r", encoding="utf-8") as f:
        advisor = json.load(f)

    cost_by_service = defaultdict(float)
    rows_by_service = defaultdict(int)
    costly_resource = defaultdict(lambda: defaultdict(float))

    for row in usage:
        blob = json.dumps(row).lower()
        svc = detect_service(blob)
        if svc not in selected_set:
            continue

        raw_cost = row.get("pretaxCost", row.get("cost", row.get("Cost", 0)))
        try:
            cost = float(raw_cost or 0)
        except (TypeError, ValueError):
            cost = 0.0

        cost_by_service[svc] += cost
        rows_by_service[svc] += 1
        costly_resource[svc][resource_identifier(row)] += cost

    findings = []
    for svc in sorted(selected_set):
        svc_cost = round(cost_by_service.get(svc, 0.0), 4)
        if svc_cost <= 0:
            continue
        est_low = round(svc_cost * 0.10, 2)
        est_high = round(svc_cost * 0.30, 2)
        largest_resource = "n/a"
        if costly_resource.get(svc):
            largest_resource = max(costly_resource[svc].items(), key=lambda kv: kv[1])[0]
        findings.append(
            {
                "id": f"{svc}-cost-concentration",
                "service": svc,
                "severity": severity_from_monthly(svc_cost),
                "effort": "quick-win",
                "message": f"{svc} has notable monthly spend concentration; prioritize rightsizing and scheduling.",
                "evidence": {
                    "usage_rows": rows_by_service.get(svc, 0),
                    "observed_monthly_cost": svc_cost,
                    "largest_resource": largest_resource,
                },
                "savings_low": est_low,
                "savings_high": est_high,
            }
        )

    advisor_count = 0
    for rec in advisor:
        svc = detect_service(json.dumps(rec))
        if svc not in selected_set:
            continue
        advisor_count += 1
        findings.append(
            {
                "id": f"{svc}-advisor-{advisor_count}",
                "service": svc,
                "severity": "medium",
                "effort": "quick-win",
                "message": rec.get("shortDescription", {}).get("problem", "Advisor cost recommendation"),
                "evidence": {
                    "recommendation_type": rec.get("recommendationTypeId"),
                    "resource_id": rec.get("resourceMetadata", {}).get("resourceId", "unknown"),
                },
                "savings_low": 25.0,
                "savings_high": 150.0,
            }
        )

    total_low = round(sum(f["savings_low"] for f in findings), 2)
    total_high = round(sum(f["savings_high"] for f in findings), 2)

    report = {
        "audit_date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "mode": "live",
        "subscription": subscription,
        "summary": {
            "finding_count": len(findings),
            "savings_low": total_low,
            "savings_high": total_high,
            "savings_annual_low": round(total_low * 12, 2),
            "savings_annual_high": round(total_high * 12, 2),
        },
        "selected_services": sorted(selected_set),
        "service_costs": {k: round(v, 4) for k, v in sorted(cost_by_service.items())},
        "findings": findings,
    }

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)


if __name__ == "__main__":
    main()
