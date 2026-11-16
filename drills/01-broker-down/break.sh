#!/usr/bin/env bash
# Drill 1: one broker dies. Kubernetes (via Strimzi) brings it back.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
echo ">>> Killing drills-broker-1"
kubectl -n kafka delete pod drills-broker-1 --wait=false
"$ROOT/scripts/watch.sh" 9 10
