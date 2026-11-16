#!/usr/bin/env bash
# Usage: scripts/watch.sh <rounds> <seconds-between>
# Prints the cluster status plus the producer's latest line, repeatedly.
DIR=$(cd "$(dirname "$0")" && pwd)
for ((i = 1; i <= ${1:-6}; i++)); do
  "$DIR/status.sh"
  echo "== producer: $(kubectl -n kafka logs deploy/producer --since=15s 2>/dev/null | grep -E 'records sent|Exception' | tail -1)"
  echo
  sleep "${2:-10}"
done
