#!/usr/bin/env python3
import argparse
import csv
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

SERVICE_KEYWORDS = {
    "virtual-machines": ["microsoft.compute", "virtual machines", "virtualmachines"],
    "aks": ["microsoft.containerservice", "kubernetes service", "aks"],
    "sql": ["microsoft.sql", "postgresql", "mysql", "sql database"],
    "storage": ["microsoft.storage", "storage", "blob"],
    "network": ["microsoft.network", "bandwidth", "data transfer", "network"],
}


def to_float(v):
    try:
        return float((v or "").strip() or 0)
    except (TypeError, ValueError):
        return 0.0


def normalize_service(s):
    return SERVICE_MAP.get((s or "").strip().lower(), "")


def detect_service(consumed_service):
    text = (consumed_service or "").lower()
    for svc, words in SERVICE_KEYWORDS.items():
        if any(w in text for w in words):
            return svc
    return "network"


def severity(cost):
    if cost >= 1000:
        return "high"
    if cost >= 250:
        return "medium"
    return "low"


def pick_cost_column(cols):
    for c in ["CostInBillingCurrency", "Cost", "PreTaxCost", "CostInUSD"]:
        if c in cols:
            return c
    return None


def top_n(d, key_name, n=10):
    return [{key_name: k, "cost": round(v, 4)} for k, v in sorted(d.items(), key=lambda kv: kv[1], reverse=True)[:n]]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", required=True)
    parser.add_argument("--services", default="virtual-machines,aks,sql,storage,network")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    selected = [normalize_service(s) for s in args.services.split(",")]
    selected = [s for s in selected if s]
    selected_set = set(selected or list(SERVICE_KEYWORDS.keys()))

    totals_by_rg = defaultdict(float)
    totals_by_subscription = defaultdict(float)
    totals_by_service = defaultdict(float)
    service_resource_count = defaultdict(int)
    resource_set_by_service = defaultdict(set)
    row_count = 0
    total_cost = 0.0
    currency = "unknown"

    with open(args.csv, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        if not reader.fieldnames:
            raise SystemExit("CSV has no header row")
        cost_col = pick_cost_column(reader.fieldnames)
        if not cost_col:
            raise SystemExit("No supported cost column found in CSV header")

        for row in reader:
            row_count += 1
            cost = to_float(row.get(cost_col))
            total_cost += cost

            rg = (row.get("ResourceGroupName") or "unknown").strip() or "unknown"
            sub = (row.get("SubscriptionId") or row.get("SubscriptionGuid") or "unknown").strip() or "unknown"
            consumed = row.get("ConsumedService") or ""
            svc = detect_service(consumed)
            meter = (row.get("MeterName") or "unknown").strip() or "unknown"
            instance = (row.get("InstanceName") or "unknown").strip() or "unknown"
            resource_id = f"{rg}|{instance}|{meter}"

            currency = (row.get("BillingCurrencyCode") or row.get("Currency") or currency).strip() or currency
            totals_by_rg[rg] += cost
            totals_by_subscription[sub] += cost
            if svc in selected_set:
                totals_by_service[svc] += cost
                resource_set_by_service[svc].add(resource_id)

    for svc in selected_set:
        service_resource_count[svc] = len(resource_set_by_service.get(svc, set()))

    findings = []
    for svc in sorted(selected_set):
        svc_cost = round(totals_by_service.get(svc, 0.0), 4)
        if svc_cost <= 0:
            continue
        low = round(svc_cost * 0.12, 2)
        high = round(svc_cost * 0.35, 2)
        findings.append(
            {
                "id": f"{svc}-export-spend",
                "service": svc,
                "severity": severity(svc_cost),
                "effort": "quick-win",
                "message": f"{svc} export spend suggests optimization opportunities (rightsizing, scheduling, storage tiering).",
                "evidence": {
                    "monthly_cost": svc_cost,
                    "resource_count": service_resource_count.get(svc, 0),
                },
                "savings_low": low,
                "savings_high": high,
            }
        )

    total_low = round(sum(f["savings_low"] for f in findings), 2)
    total_high = round(sum(f["savings_high"] for f in findings), 2)

    output = {
        "audit_date_utc": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "timestamp_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "source": "azure-export-csv",
        "selected_services": sorted(selected_set),
        "summary": {
            "rows": row_count,
            "total_cost": round(total_cost, 4),
            "currency": currency,
            "finding_count": len(findings),
            "savings_low": total_low,
            "savings_high": total_high,
            "savings_annual_low": round(total_low * 12, 2),
            "savings_annual_high": round(total_high * 12, 2),
        },
        "top_resource_groups": top_n(totals_by_rg, "resource_group", 10),
        "top_services": top_n(totals_by_service, "service", 10),
        "top_subscriptions": top_n(totals_by_subscription, "subscription_id", 10),
        "findings": findings,
    }

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2)


if __name__ == "__main__":
    main()
