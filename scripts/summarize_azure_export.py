#!/usr/bin/env python3
import argparse
import csv
import json
from collections import defaultdict
from datetime import datetime, timezone


def to_float(value: str) -> float:
    if value is None:
        return 0.0
    value = value.strip()
    if not value:
        return 0.0
    try:
        return float(value)
    except ValueError:
        return 0.0


def pick_cost_column(fieldnames):
    candidates = [
        "CostInBillingCurrency",
        "Cost",
        "PreTaxCost",
        "CostInUSD",
    ]
    for name in candidates:
        if name in fieldnames:
            return name
    return None


def main():
    parser = argparse.ArgumentParser(description="Summarize Azure Cost Management export CSV")
    parser.add_argument("--csv", required=True, help="Path to Azure export CSV")
    parser.add_argument("--out", required=True, help="Output JSON path")
    args = parser.parse_args()

    totals_by_rg = defaultdict(float)
    totals_by_service = defaultdict(float)
    totals_by_subscription = defaultdict(float)
    row_count = 0
    total_cost = 0.0
    currency = "unknown"

    with open(args.csv, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        if not reader.fieldnames:
            raise SystemExit("CSV has no header row")

        cost_col = pick_cost_column(reader.fieldnames)
        if cost_col is None:
            raise SystemExit("No supported cost column found in CSV header")

        for row in reader:
            row_count += 1
            cost = to_float(row.get(cost_col, "0"))
            total_cost += cost

            rg = (row.get("ResourceGroupName") or "unknown").strip() or "unknown"
            service = (row.get("ConsumedService") or "unknown").strip() or "unknown"
            sub = (row.get("SubscriptionId") or row.get("SubscriptionGuid") or "unknown").strip() or "unknown"
            currency = (row.get("BillingCurrencyCode") or row.get("Currency") or currency).strip() or currency

            totals_by_rg[rg] += cost
            totals_by_service[service] += cost
            totals_by_subscription[sub] += cost

    def top_n(d, key_name, n=10):
        return [
            {key_name: k, "cost": round(v, 4)}
            for k, v in sorted(d.items(), key=lambda kv: kv[1], reverse=True)[:n]
        ]

    output = {
        "audit_date_utc": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "timestamp_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "source": "azure-export-csv",
        "summary": {
            "rows": row_count,
            "total_cost": round(total_cost, 4),
            "currency": currency,
        },
        "top_resource_groups": top_n(totals_by_rg, "resource_group", 10),
        "top_services": top_n(totals_by_service, "service", 10),
        "top_subscriptions": top_n(totals_by_subscription, "subscription_id", 10),
    }

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2)


if __name__ == "__main__":
    main()
