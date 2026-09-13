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

```bash
DUR=30s CONC=4 bash hack/lab-two-latency.sh
```
