#!/usr/bin/env bash
# One-shot health view: broker pods, partition leaders/ISR, under-replicated
# partitions and consumer lag.
set -uo pipefail
NS=kafka
BS=drills-kafka-bootstrap:9092
k() { kubectl -n "$NS" exec toolbox -- "$@" 2>/dev/null; }

echo "== $(date +%H:%M:%S) broker pods"
kubectl -n "$NS" get pods -l strimzi.io/pool-name=broker --no-headers \
  -o custom-columns=POD:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready 2>/dev/null \
  || echo "(none)"

echo "== partitions (leader / replicas / in-sync replicas)"
k bin/kafka-topics.sh --bootstrap-server "$BS" --describe --topic orders \
  | awk -F'\t' '/Partition: [0-9]/ {print "  "$3"  "$4"  "$5"  "$6}'

URP=$(k bin/kafka-topics.sh --bootstrap-server "$BS" --describe --under-replicated-partitions --topic orders | grep -c Partition:)
echo "== under-replicated partitions: ${URP:-?}"

echo "== consumer lag (group orders-app)"
k bin/kafka-consumer-groups.sh --bootstrap-server "$BS" --describe --group orders-app \
  | awk 'NR>1 && $1=="orders-app" {sum+=$6; print "  p"$3, "lag="$6} END {print "  total lag=" sum+0}'
