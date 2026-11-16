# Runbook: consumer lag is growing

## Symptom
- Alert: consumer group lag rising for several minutes.
- Downstream data is late; the brokers themselves look healthy.

## What happened in the drill
Scaled the `orders-app` consumer to 0 for about 70 s, producer still at 50 msg/s.

| Time | Total lag |
|---|---|
| Before | ~14 (normal: offsets are committed every few seconds) |
| +18 s | 174 |
| +36 s | 580 |
| +54 s | 1,493 |
| +70 s | 2,403 (peak) |
| Consumer back, +18 s | 91: **caught up in under 18 s** |

Lag grew at the producer's rate (~50 msg/s). The producer did not notice. That is the
point of Kafka: producers and consumers are decoupled, and data waits on disk.

## Check
```bash
scripts/status.sh   # lag per partition
kubectl -n kafka exec toolbox -- bin/kafka-consumer-groups.sh \
  --bootstrap-server drills-kafka-bootstrap:9092 --describe --group orders-app
```
- "has no active members": consumers are down. Check their pods.
- Members present but lag still rising: consumers are too slow.
- Lag on one partition only: a stuck consumer, or a hot partition (uneven keys).
- Frequent rebalances in consumer logs: consumers crashing or exceeding `max.poll.interval.ms`.

## Fix
1. Consumers down: restart them, check why they stopped.
2. Too slow: add consumers, up to the number of partitions. More consumers than
   partitions do nothing; beyond that, add partitions.
3. Make sure lag will drain before retention deletes the data (`retention.ms`),
   or messages are lost to the consumer.

## Done when
Lag is falling, and back to its normal small number.
