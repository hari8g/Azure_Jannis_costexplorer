#!/usr/bin/env python3
import argparse
import glob
import json
import os
from datetime import datetime, timezone


def load_reports(report_dir):
    files = sorted(glob.glob(os.path.join(report_dir, "*.json")))
    reports = []
    for path in files:
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
                data["_file"] = os.path.basename(path)
                reports.append(data)
        except Exception:
            continue
    return reports


def get_summary(report):
    summary = report.get("summary", {})
    findings = summary.get("finding_count", 0)
    low = summary.get("savings_low", 0)
    high = summary.get("savings_high", 0)
    return findings, low, high


def render_html(reports, title):
    total_findings = 0
    total_low = 0.0
    total_high = 0.0
    rows = []

    for r in reports:
        findings, low, high = get_summary(r)
        total_findings += findings
        total_low += float(low or 0)
        total_high += float(high or 0)
        rows.append(
            f"<tr><td>{r.get('_file','n/a')}</td><td>{r.get('mode', r.get('source','n/a'))}</td>"
            f"<td>{findings}</td><td>{low}</td><td>{high}</td></tr>"
        )

    generated = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    table_rows = "\n".join(rows) if rows else "<tr><td colspan='5'>No reports found</td></tr>"

    return f"""<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <title>{title}</title>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 24px; background: #f9fafb; color: #111827; }}
    h1 {{ margin-bottom: 6px; }}
    .meta {{ color: #6b7280; margin-bottom: 20px; }}
    .cards {{ display: flex; gap: 12px; margin-bottom: 20px; flex-wrap: wrap; }}
    .card {{ background: white; border: 1px solid #e5e7eb; border-radius: 8px; padding: 12px 16px; min-width: 220px; }}
    table {{ width: 100%; border-collapse: collapse; background: white; border: 1px solid #e5e7eb; }}
    th, td {{ border-bottom: 1px solid #e5e7eb; text-align: left; padding: 10px; }}
    th {{ background: #f3f4f6; }}
  </style>
</head>
<body>
  <h1>{title}</h1>
  <div class="meta">Generated (UTC): {generated}</div>
  <div class="cards">
    <div class="card"><strong>Reports</strong><div>{len(reports)}</div></div>
    <div class="card"><strong>Total Findings</strong><div>{total_findings}</div></div>
    <div class="card"><strong>Total Savings (Low)</strong><div>{round(total_low,2)}</div></div>
    <div class="card"><strong>Total Savings (High)</strong><div>{round(total_high,2)}</div></div>
  </div>
  <table>
    <thead>
      <tr><th>Report</th><th>Mode</th><th>Findings</th><th>Savings Low</th><th>Savings High</th></tr>
    </thead>
    <tbody>
      {table_rows}
    </tbody>
  </table>
</body>
</html>"""


def main():
    parser = argparse.ArgumentParser(description="Generate HTML dashboard from report JSON files")
    parser.add_argument("--reports", default="./reports", help="Directory containing JSON reports")
    parser.add_argument("--out", default="./reports/dashboard.html", help="Output HTML file path")
    parser.add_argument("--title", default="Azure FinOps Dashboard", help="Dashboard title")
    args = parser.parse_args()

    reports = load_reports(args.reports)
    html = render_html(reports, args.title)
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(html)
    print(args.out)


if __name__ == "__main__":
    main()
