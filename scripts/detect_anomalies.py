#!/usr/bin/env python3
import argparse
import glob
import json
import math
import os
from datetime import datetime, timezone


def load_current_report(path):
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    return float(data.get("summary", {}).get("savings_high", 0.0) or 0.0), data


def load_historical_values(history_dir):
    values = []
    for path in sorted(glob.glob(os.path.join(history_dir, "*.json"))):
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            val = float(data.get("summary", {}).get("savings_high", 0.0) or 0.0)
            values.append(val)
        except Exception:
            continue
    return values


def stats(vals):
    if not vals:
        return 0.0, 0.0
    mean = sum(vals) / len(vals)
    if len(vals) == 1:
        return mean, 0.0
    variance = sum((x - mean) ** 2 for x in vals) / len(vals)
    return mean, math.sqrt(variance)


def main():
    parser = argparse.ArgumentParser(description="Detect anomaly against historical report trends")
    parser.add_argument("--current-report", required=True)
    parser.add_argument("--history-dir", required=True)
    parser.add_argument("--z-threshold", type=float, default=2.5)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    current_value, current_report = load_current_report(args.current_report)
    historical = load_historical_values(args.history_dir)
    mean, std = stats(historical)
    z = 0.0 if std == 0 else (current_value - mean) / std
    is_anomaly = len(historical) >= 3 and abs(z) >= args.z_threshold

    result = {
        "timestamp_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "current_report": args.current_report,
        "history_dir": args.history_dir,
        "metric": "summary.savings_high",
        "current_value": current_value,
        "history_count": len(historical),
        "history_mean": round(mean, 4),
        "history_stddev": round(std, 4),
        "z_score": round(z, 4),
        "z_threshold": args.z_threshold,
        "anomaly_detected": is_anomaly,
        "severity": "high" if is_anomaly else "info",
        "message": (
            "Potential anomaly in savings_high trend."
            if is_anomaly
            else "No anomaly detected for savings_high trend."
        ),
        "context": {
            "summary": current_report.get("summary", {}),
            "mode": current_report.get("mode", current_report.get("source", "unknown")),
        },
    }

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2)

    print(args.out)


if __name__ == "__main__":
    main()
