# Runbook: writes rejected, not enough in-sync replicas

## Symptom
- Producers fail with `NOT_ENOUGH_REPLICAS`, then `TimeoutException` (records expire).
- `UnderReplicatedPartitions` high; ISR has fewer brokers than `min.insync.replicas`.
- Consumers see no new data (lag stays at 0 because nothing new is written).

## What happened in the drill
Stopped the Strimzi operator (so pods stay dead), then killed 2 of 3 brokers.
Topic: replication factor 3, `min.insync.replicas=2`, producer `acks=all`.

| Time | What we saw |
|---|---|
| +0 s | ISR for every partition shrank to `0`. Broker 0 became leader of all 3. |
| +0 to ~3.5 min | Brokers answered `NOT_ENOUGH_REPLICAS` 1,079 times. The producer retried until its 10 s delivery timeout, then the records expired: **writes rejected, nothing stored that could be lost.** |
| Operator back | Brokers recreated, ISR back to `0,1,2` within ~25 s. |
| Recovery | Producer drained its backlog (91 msg/s for one interval, 8.7 s max latency), then back to 50 msg/s at ~7 ms. |
| ~4 min later | Kafka moved leadership back to the preferred brokers (`1, 2, 0`) on its own. |

## The trade-off
`acks=all` + `min.insync.replicas=2` chooses **safety over availability**: Kafka would
rather refuse a write than accept it on one broker, which could die and take the
only copy with it. With `acks=1`, the writes would have succeeded, but would
have lived on a single broker.

## Check
```bash
scripts/status.sh                                   # ISR per partition
kubectl -n kafka get pods                           # which brokers are down
kubectl -n kafka get deploy strimzi-cluster-operator  # is the operator running?
kubectl -n kafka logs deploy/producer | grep -oE "Error: [A-Z_]+" | sort | uniq -c
```

## Fix
1. Bring brokers back: here, scale the operator back to 1; in real life, fix why
   they are down (node failure, disk, memory).
2. Do **not** lower `min.insync.replicas` to get writes flowing, except as a
   deliberate decision to accept possible data loss.
3. Producers must handle the failure: retry, buffer, or alert. Rejected records
   are only safe if the application notices.
4. Afterwards, check leaders rebalance (see drill 1).

## Done when
ISR is back to all replicas, producers report no errors, and consumers catch up.
