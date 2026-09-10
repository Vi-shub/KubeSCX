# Lab 3: Benchmark P99 under contention

This is the flagship experiment. Same load, two schedulers.

```bash
sed -i 's/\r$//' hack/*.sh   # if scripts were copied from Windows
bash hack/lab-local.sh
```

The script:

1. Starts `latency-server` (the SLO stand-in) and `cpu-burn` (background).
2. Measures p50 / p95 / p99 / p99.9 against the **default** Linux scheduler.
3. Loads `scx_kube`, classifies the two PIDs, measures again.
4. Prints a table.

## Recorded result (Linux 7.0.0-30-generic)

Same-node lab, 15s, 8 clients, 800µs CPU work per request, `cpu-burn` workers=`nproc`.

```
scheduler          p50_ms   p95_ms   p99_ms  p99.9_ms      rps
default              4.08    15.08    22.44     34.83   1409.2
scx_kube             3.02     5.92     7.27     10.50   2387.5
p99 change vs default: +67.6%
```

Counters at the end of the winning run:

```
enq lat=11376 def=15456 bg=142  disp lat=11376 def=15455 bg=139  idle=38 kick=528
```

Enqueue ≈ dispatch (no lost tasks). `kick` is tick-driven yields, not a preempt storm.

This is one workload on one kernel, not a claim that scx_kube wins everywhere.

## Failed runs we kept

1. **Idle LOCAL path for background.** Burners skipped the background queue. p99 ~23ms to ~699ms.
2. **SCX_KICK_PREEMPT on every latency enqueue.** Go threads re-enqueued constantly; ~6.4M kicks / 15s. p95 improved, p99 ~423ms.

Both are the kind of negative result the project is supposed to document.

## How to read a new run

- **p99 down, rps up or only slightly down:** latency class stole CPU from the burner without stalling the client.
- **p99 unchanged:** classification missed, or the node was not contended. Check counters.
- **p99 up with kick ≈ enq lat:** preempt storm. Do not kick on every enqueue.
- **p99 up with disp lat << enq lat:** dispatch is not consuming the latency DSQ.

## Variables worth changing

```bash
DUR=30s CONC=16 bash hack/lab-local.sh
```

Repeat the winning config three times before treating the table as stable. Edit `cmd/latency-server` `-work-us` to change how CPU-heavy each request is.

## Kubernetes variant

After `sudo make install` and `kubectl apply -f deploy/lab`, run the loadgen Job in `deploy/lab/05-loadgen.yaml` once with `scx_kube` unloaded and once loaded. Keep CPU **limits** off the lab pods so CFS quota does not hide scheduler effects.
