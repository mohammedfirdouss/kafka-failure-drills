# Kafka failure drills

A 3-broker Kafka cluster on Kubernetes, broken on purpose in three ways, with what
actually happened and a runbook for each.

Runs locally on kind with the [Strimzi](https://strimzi.io) operator (Strimzi 1.3.1, Kafka 4.3.2, KRaft).

## Setup

| Part | Detail |
|---|---|
| Cluster | 1 KRaft controller + 3 brokers (separate pools, so killing brokers never breaks the metadata quorum) |
| Topic `orders` | 3 partitions, replication factor 3, `min.insync.replicas=2` |
| Producer | 50 msg/s, `acks=all`, 10 s delivery timeout (so failures show quickly) |
| Consumer | One consumer in group `orders-app` |

## Results

| Drill | What we broke | What happened | Runbook |
|---|---|---|---|
| [1. Broker down](drills/01-broker-down) | Killed 1 of 3 brokers | All partitions under-replicated, one leader failed over, one 503 ms latency spike, **no errors**. Back in sync in ~25 s. | [runbook](drills/01-broker-down/runbook.md) |
| [2. Consumer lag](drills/02-consumer-lag) | Stopped the consumer for ~70 s | Lag grew at ~50 msg/s to 2,403. Producer unaffected. Caught up in under 18 s once restarted. | [runbook](drills/02-consumer-lag/runbook.md) |
| [3. Not enough replicas](drills/03-not-enough-replicas) | Killed 2 of 3 brokers (operator stopped so they stay down) | Brokers returned `NOT_ENOUGH_REPLICAS` 1,079 times; writes **rejected for ~3.5 min rather than stored on one broker**. Full recovery once brokers returned. | [runbook](drills/03-not-enough-replicas/runbook.md) |

Each drill folder has `break.sh` (the drill), `output.txt` (the real run) and `runbook.md`.

## What I learned

1. **One broker down is a non-event** when replication factor is 3 and `min.insync.replicas=2`. The
   alert to watch is `UnderReplicatedPartitions`, not producer errors.
2. **Lag is a consumer problem, not a broker problem.** Kafka holds the data; the question is
   whether consumers catch up before retention deletes it.
3. **`acks=all` + `min.insync.replicas` trades availability for safety.** With 2 brokers gone, Kafka
   refused writes instead of keeping a single copy. The producer must handle that failure.
4. **After recovery, leadership is uneven.** Returning brokers come back as followers. Kafka moves
   leaders back on its own every 5 minutes (`auto.leader.rebalance.enable`), or you can force it with
   `kafka-leader-election.sh --election-type PREFERRED`.

## Run it

Needs Docker (about 6 GB RAM), kind and kubectl.

```bash
scripts/up.sh                              # cluster, Strimzi, Kafka, traffic (first run downloads images)
scripts/status.sh                          # pods, leaders, ISR, under-replicated partitions, lag
drills/01-broker-down/break.sh
drills/02-consumer-lag/break.sh
drills/03-not-enough-replicas/break.sh
scripts/down.sh                            # delete everything
```

## Layout

```
cluster/   kind.yaml, kafka.yaml (node pools, Kafka, topic), load.yaml (producer, consumer, toolbox)
scripts/   up.sh, down.sh, status.sh, watch.sh
drills/    one folder per drill: break.sh, output.txt, runbook.md
```
