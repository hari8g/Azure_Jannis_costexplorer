# Multi-Subscription / Multi-Account Guide

Azure equivalent of AWS multi-account wrapper:

```bash
./multi-account-audit.sh --profiles sub1,sub2,sub3 --services virtual-machines,aks
```

Notes:
- `--profiles` maps to Azure subscription IDs.
- Wrapper delegates to `multi-subscription-audit.sh`.
