# Runbook: a broker is down

## Symptom
- Alert: `UnderReplicatedPartitions > 0`.
- A broker pod is not Ready, or is restarting.
- Producers may see a short latency spike while leaders move.

## What happened in the drill
Killed `drills-broker-1` under 50 msg/s of `acks=all` traffic.

| Time | What we saw |
|---|---|
| +0 s | All 3 partitions under-replicated. ISR shrank from `0,1,2` to two brokers. |
| +0 s | Partition 0's leader moved from broker 1 to broker 2 (failover). |
| +0 s | Producer: one spike to 503 ms max latency. **No errors, no lost writes.** |
| ~25 s | Strimzi recreated the pod. Broker caught up; ISR back to `0,1,2`. |

Why no errors: 2 of 3 replicas stayed in sync, which meets `min.insync.replicas=2`.

## Check
```bash
scripts/status.sh                         # pods, leaders, ISR, URP, lag
kubectl -n kafka get pods -l strimzi.io/pool-name=broker
kubectl -n kafka describe pod <broker>    # OOMKilled? evicted? failing probes?
kubectl -n kafka logs <broker> --previous # why the last run died
```

## Cause (common ones)
- Pod deleted, node drained, or evicted.
- OOMKilled: heap or container memory too small.
- Disk full: broker shuts down when it cannot write its log.

## Fix
1. Usually none: the operator restarts the broker and it re-syncs.
2. If it keeps crashing, fix the cause from `describe` / `--previous` logs (memory, disk).
3. After recovery, check leaders are balanced. A returning broker is a follower until
   leadership is moved back. Kafka does this itself (`auto.leader.rebalance.enable=true`,
   checked every 300 s), or force it:
   ```bash
   kubectl -n kafka exec toolbox -- bin/kafka-leader-election.sh \
     --bootstrap-server drills-kafka-bootstrap:9092 --election-type PREFERRED --all-topic-partitions
   ```

## Done when
`UnderReplicatedPartitions = 0`, all brokers Ready, leaders spread across brokers.
