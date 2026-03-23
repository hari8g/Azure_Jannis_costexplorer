FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    jq \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app
RUN chmod +x ./build.sh ./setup.sh ./live-audit.sh ./cur-audit.sh ./export-audit.sh ./ci-entrypoint.sh ./multi-account-audit.sh ./multi-subscription-audit.sh ./phase4-governance.sh ./dashboard/dashboard-gen.sh ./alerts/notify.sh ./tests/run-tests.sh

ENTRYPOINT ["./ci-entrypoint.sh"]
