#!/usr/bin/env bash
# Drill 2: the consumer stops while the producer keeps sending. Lag grows,
# then drains when the consumer comes back.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
echo ">>> Stopping the consumer"
kubectl -n kafka scale deploy/consumer --replicas=0
"$ROOT/scripts/watch.sh" 4 15
echo ">>> Starting the consumer again"
kubectl -n kafka scale deploy/consumer --replicas=1
"$ROOT/scripts/watch.sh" 4 15
