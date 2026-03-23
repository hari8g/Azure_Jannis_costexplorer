# Azure Migration Plan (From AWS Audit Structure)

This document maps the AWS-oriented structure to Azure services so the toolkit can scale to parity over time.

## Service Mapping

- `ec2` -> Virtual Machines / VM Scale Sets
- `eks` -> AKS
- `ecs` -> Container Apps / AKS workloads
- `rds` -> Azure SQL / PostgreSQL Flexible Server / MySQL Flexible Server
- `s3` -> Azure Storage (Blob, Files, Queues, Tables)
- `lambda` -> Azure Functions
- `cloudfront` -> Front Door / CDN
- `elasticache` -> Azure Cache for Redis
- `dynamodb` -> Cosmos DB
- `sqs-sns` -> Service Bus / Event Grid
- `kinesis-msk` -> Event Hubs
- `step-functions` -> Logic Apps / Durable Functions
- `api-gateway` -> API Management

## Phase 1 (Current Starter)

- Shared helper library
- Setup and dependency checks
- Live subscription + advisor + usage pull
- Export CSV summarization
- Report generation in text + JSON

## Phase 2

- Service-specific modules under `services/<service>/live` and `services/<service>/export`
- Savings heuristics and severity scoring
- Baseline comparison (`new/fixed/regressed`)

### Phase 2 Status

- Implemented service module skeletons for:
  - `virtual-machines`
  - `aks`
  - `sql`
  - `storage`
  - `network`
- Implemented centralized findings generation for live and export modes
- Implemented baseline diff support (`new`/`fixed` arrays)

## Phase 3

- Multi-subscription runner
- HTML dashboard
- CI automation and policy gating

### Phase 3 Status

- Implemented `multi-subscription-audit.sh` for cross-subscription live aggregation
- Implemented dashboard generator:
  - `dashboard/dashboard-gen.py`
  - `dashboard/dashboard-gen.sh`
- Implemented CI policy gate workflow:
  - `.github/workflows/ci-policy-gates.yml`
- Implemented policy check utility:
  - `scripts/policy_gate.py`

## Phase 4

- Cost anomaly detection and alerting
- Tag compliance checks and governance thresholds
- Alert payload generation and notification wiring

### Phase 4 Status (Milestone 1)

- Implemented anomaly detection:
  - `scripts/detect_anomalies.py`
- Implemented tag compliance checks:
  - `scripts/check_tag_compliance.py`
- Implemented alert payload builder:
  - `scripts/build_alert_payload.py`
- Implemented governance orchestrator:
  - `phase4-governance.sh`
- Implemented notification utility:
  - `alerts/notify.sh`
- Added governance CI workflow:
  - `.github/workflows/phase4-governance.yml`
