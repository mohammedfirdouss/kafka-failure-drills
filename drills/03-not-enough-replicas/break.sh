#!/usr/bin/env bash
# Drill 3: two of three brokers are down. With acks=all and
# min.insync.replicas=2, Kafka refuses writes it cannot keep safe.
# The Strimzi operator is scaled to 0 first so the brokers stay down.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
echo ">>> Stopping the Strimzi operator so killed brokers are not recreated"
kubectl -n kafka scale deploy/strimzi-cluster-operator --replicas=0
kubectl -n kafka rollout status deploy/strimzi-cluster-operator --timeout=60s
echo ">>> Killing drills-broker-1 and drills-broker-2"
kubectl -n kafka delete pod drills-broker-1 drills-broker-2
"$ROOT/scripts/watch.sh" 4 15
echo ">>> Recovering: starting the operator, which recreates the brokers"
kubectl -n kafka scale deploy/strimzi-cluster-operator --replicas=1
"$ROOT/scripts/watch.sh" 10 15
