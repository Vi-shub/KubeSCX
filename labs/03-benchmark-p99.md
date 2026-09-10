# Lab 3 — Benchmark P99 under contention

This is the flagship experiment. Same load, two schedulers.

```bash
make lab-local
```

The script:

1. Starts `latency-server` (the SLO stand-in) and `cpu-burn` (background).
2. Measures p50 / p95 / p99 / p99.9 against the **default** Linux scheduler.
3. Loads `scx_kube`, classifies the two PIDs, measures again.
4. Prints a table.

Example shape (numbers will differ; these are not claims):

```
scheduler         p50_ms   p95_ms   p99_ms  p99.9_ms      rps
default            12.40    40.10   180.00    240.00    620.0
scx_kube            8.10    18.40    90.00    140.00    590.0
p99 change vs default: +50.0%  (positive means scx_kube is better)
```

## How to read it

- **p99 down, rps only slightly down** — the policy did what we hoped: steal CPU from the burner for the latency process.
- **p99 unchanged** — classification missed, the node was not actually contended, or EEVDF was already good enough. Check `scx_kube` counters.
- **p99 up** — also useful. File it as a negative result; do not hide it.

## Variables worth changing

```bash
DUR=30s CONC=16 make lab-local
```

Edit `cmd/latency-server` work time (`-work-us`) to make each request more or less CPU-heavy.

## Kubernetes variant

After `sudo make install` and `kubectl apply -f deploy/lab`, run the loadgen Job in `deploy/lab/05-loadgen.yaml` once with `scx_kube` unloaded and once loaded. Compare Job logs the same way. Keep CPU **limits** off the lab pods so CFS quota does not hide scheduler effects.
