# Service Contract

## Report Contract

Every JSON report should include:

- `summary.finding_count`
- `summary.savings_low`
- `summary.savings_high`
- `findings[]`

## Baseline Diff Contract

When baseline is provided:

- `baseline_diff.new[]`
- `baseline_diff.fixed[]`
- `baseline_diff.regressed[]`
