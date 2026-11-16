#!/usr/bin/env bash
# Create the kind cluster, install Strimzi, deploy Kafka and start traffic.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
kind create cluster --config "$ROOT/cluster/kind.yaml"
kubectl create namespace kafka
# Strimzi 1.3.1, pinned. The release file targets namespace "myproject", so rewrite it.
curl -sL https://github.com/strimzi/strimzi-kafka-operator/releases/download/1.3.1/strimzi-cluster-operator-1.3.1.yaml \
  | sed 's/namespace: .*/namespace: kafka/' | kubectl -n kafka create -f -
kubectl -n kafka rollout status deploy/strimzi-cluster-operator --timeout=900s
kubectl -n kafka apply -f "$ROOT/cluster/kafka.yaml"
kubectl -n kafka wait kafka/drills --for=condition=Ready --timeout=900s
kubectl -n kafka apply -f "$ROOT/cluster/load.yaml"
kubectl -n kafka wait --for=condition=Ready pod/toolbox --timeout=300s
"$ROOT/scripts/status.sh"
