# Results

## First recorded run

**Linux 7.0.0-30-generic**, 15s, 8 clients, 800µs CPU per request, `cpu-burn -workers $(nproc)`.

| scheduler | p50 | p95 | p99 | p99.9 | rps |
|-----------|-----|-----|-----|-------|-----|
| default Linux | 4.08 ms | 15.08 ms | 22.44 ms | 34.83 ms | 1409 |
| scx_kube | 3.02 ms | 5.92 ms | **7.27 ms** | 10.50 ms | **2388** |

```
enq lat=11376 def=15456 bg=142  disp lat=11376 def=15455 bg=139  idle=38 kick=528
```

## Soak (repeatable)

**Linux 7.0.0-31-generic**, same node, 30s, 8 clients. Three runs, no code changes. `out/soak-20260915T134959Z`.

| run | default p99 | scx p99 | default rps | scx rps |
|-----|-------------|---------|-------------|---------|
| 1 | 22.00 ms | 7.00 ms | 1401 | 2386 |
| 2 | 22.04 ms | 7.00 ms | 1385 | 2386 |
| 3 | 23.55 ms | 7.25 ms | 1399 | 2386 |

p99 stayed ~7 ms. scx rps was the same every run. Kick ~1100 / 30s, not millions. `enq` ≈ `disp`. Background still ran a little.

A 15s run on the same kernel the same day: default p99 23.05 ms, scx 7.14 ms, rps 1386 → 2389, `kick=537`.

!!! warning "Scope"
    One kernel family (Linux 7.0), one node, synthetic spin, loadgen on the same machine. Do not say Kubernetes is 68% faster.

## Two latency processes

**Linux 7.0.0-31-generic**, two `latency-server` processes, one burner, loadgen against both at once.

| run | p50 | p95 | p99 | rps |
|-----|-----|-----|-----|-----|
| default-a | 3.11 ms | 9.99 ms | 13.84 ms | 1028 |
| default-b | 3.64 ms | 10.18 ms | 14.84 ms | 950 |
| scx-a | 3.36 ms | 5.01 ms | **7.55 ms** | 1172 |
| scx-b | 3.35 ms | 5.02 ms | **7.52 ms** | 1174 |

```
enq lat=35363 def=26280 bg=4  disp lat=35363 def=26275 bg=1  idle=23 kick=871
```

scx-a and scx-b matched. They shared the latency FIFO. They did not each get a reserved CPU (total scx rps ≈ one-server lab). Background almost did not run (`bg=4`). That is the policy: when two latency workloads keep the node busy, batch is last.

## Single-node Kubernetes (k3s)

**Linux 7.0.0-31-generic**, same box, k3s. Pod label `scheduling.ebpf.io/class` → cgroup inode (3 cgroups per pod, including the cri-containerd scope). `out/k8s-20260915T140423Z`.

| scheduler | p50 | p95 | p99 | p99.9 | rps |
|-----------|-----|-----|-----|-------|-----|
| default Linux (run 1) | 6.94 ms | 146.5 ms | **325.1 ms** | 630 ms | 266 |
| scx_kube (run 1) | 3.39 ms | 6.04 ms | **7.54 ms** | 10.37 ms | **2237** |
| default Linux (run 2) | 9.95 ms | 153.5 ms | **274.1 ms** | 483 ms | 248 |
| scx_kube (run 2) | 3.39 ms | 6.03 ms | **7.40 ms** | 10.22 ms | **2253** |

Agent mapped payment-api as latency and batch-job as background. During the job:

```
enq lat=32123 def=72822 bg=760  disp lat=32123 def=72817 bg=757  idle=42 kick=2629
```

After loadgen exited, `enq lat` froze and `bg` kept climbing (k3s + burner). That is expected.

This is **not** the same experiment as the host `lab-local` 22 ms table. Loadgen goes through a ClusterIP Service, k3s is running, the burner is a Pod. The default p99 is worse because the node is busier and the path is longer. scx_kube still brought p99 back to ~7.5 ms, same ballpark as the host lab. Do not headline this as "Kubernetes is 97% faster."

## Failed runs (kept on purpose)

| Policy | What happened | p99 |
|--------|----------------|-----|
| Background allowed on idle LOCAL | Burners skipped the background queue | ~23 ms → ~699 ms |
| `SCX_KICK_PREEMPT` on every latency enqueue | ~6.4M kicks / 15s (Go thread storm) | p95 better, p99 ~423 ms |

Full narrative: [First P99 result](blog/first-p99-result.md). Counters: [lesson 4](teach/04-read-counters.md).

## Reproduce

```bash
git clone https://github.com/Vi-shub/KubeSCX.git
cd KubeSCX
make check && make scheduler
sed -i 's/\r$//' hack/*.sh
bash hack/lab-local.sh
RUNS=3 DUR=30s bash hack/lab-soak.sh
bash hack/lab-two-latency.sh
bash hack/lab-k8s.sh
```
