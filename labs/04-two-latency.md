# Lab 4: Two latency processes, one burner

The first lab asks whether a latency class beats a burner. This one asks the next question:

> If two processes are both `latency`, do they both stay ahead of background, or does one of them eat the queue?

Both answers are useful. The latency DSQ is FIFO, not a reserved CPU per Pod.

```bash
sed -i 's/\r$//' hack/*.sh
bash hack/lab-two-latency.sh
```

The script starts two `latency-server` processes (`:8080` and `:8081`), one `cpu-burn`, then runs loadgen against **both at once**.

## What to look for

| Pattern | Likely meaning |
|---------|----------------|
| Both scx p99 numbers beat default, and they are close | Shared latency queue, burner stayed last |
| Both beat default, but one p99 is much worse | FIFO burstiness among latency tasks |
| Neither improves | Classification missed, or the node was not contended |
| `enq lat` about twice the first lab, `kick` still hundreds | Two latency TGIDs, no preempt storm |

Paste kernel, both rows, and the counter line. A messy table is still a lab report.

## Recorded (Linux 7.0.0-31-generic)

| run | p50 | p95 | p99 | rps |
|-----|-----|-----|-----|-----|
| default-a | 3.11 ms | 9.99 ms | 13.84 ms | 1028 |
| default-b | 3.64 ms | 10.18 ms | 14.84 ms | 950 |
| scx-a | 3.36 ms | 5.01 ms | 7.55 ms | 1172 |
| scx-b | 3.35 ms | 5.02 ms | 7.52 ms | 1174 |

scx-a ≈ scx-b. Shared queue, not two reserved CPUs. `bg=4`: the burner barely ran once latency filled the machine.

```bash
DUR=30s CONC=4 bash hack/lab-two-latency.sh
```
