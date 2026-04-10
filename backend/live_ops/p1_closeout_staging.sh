#!/usr/bin/env bash
set -euo pipefail

echo "Running P1 staging closeout checks"

bash backend/live_ops/run_push_worker_staging_checks.sh
bash backend/live_ops/apns_worker_smoke.sh

echo "P1 staging closeout checks passed"
