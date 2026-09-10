# Results

Recorded on **Linux 7.0.0-30-generic**, same node, 15 seconds, 8 clients, 800µs CPU work per request, `cpu-burn -workers $(nproc)`.

## Winning run

| scheduler | p50 | p95 | p99 | p99.9 | rps |
|-----------|-----|-----|-----|-------|-----|
| default Linux | 4.08 ms | 15.08 ms | 22.44 ms | 34.83 ms | 1409 |
| scx_kube | 3.02 ms | 5.92 ms | **7.27 ms** | 10.50 ms | **2388** |

p99 improved about **68%**. Throughput went up.

```
enq lat=11376 def=15456 bg=142  disp lat=11376 def=15455 bg=139  idle=38 kick=528
```

Enqueue matches dispatch. Kick is hundreds, not millions. Background still ran a little.

!!! warning "Scope"
    One kernel, one node, synthetic spin, loadgen on the same machine. Repeat the lab before treating the table as stable. Do not say Kubernetes is 68% faster.

## Failed runs (kept on purpose)

| Policy | What happened | p99 |
|--------|----------------|-----|
| Background allowed on idle LOCAL | Burners skipped the background queue | ~23 ms → ~699 ms |
| `SCX_KICK_PREEMPT` on every latency enqueue | ~6.4M kicks / 15s (Go thread storm) | p95 better, p99 ~423 ms |

Full narrative: [First P99 result](blog/first-p99-result.md). How to read counters: [lesson 4](teach/04-read-counters.md).

## Reproduce

```bash
git clone https://github.com/Vi-shub/KubeSCX.git
cd KubeSCX
make check && make scheduler
sed -i 's/\r$//' hack/*.sh
bash hack/lab-local.sh
```
