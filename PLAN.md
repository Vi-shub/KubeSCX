# KubeSCX plan (30 days)

Kubernetes can mark a Pod as latency-sensitive. Linux schedules threads. KubeSCX maps that class onto three FIFO CPU queues and measures p99.

**What "prod" means here:** a dedicated throwaway VM or single k3s node you can reboot. Not a shared cluster. Not a laptop you need. `scx_kube` is the CPU scheduler for the whole machine while it is loaded.

## 30-day target (by mid-October 2026)

A node-shaped test you can repeat:

1. Three `lab-local` tables on the same kernel (not one lucky run).
2. One `lab-two-latency` table.
3. One soak (several 30s+ runs in a row, results in `out/soak-*`).
4. One single-node k8s path: Pod label → cgroup map → same loadgen, with and without `scx_kube`.
5. A written go / no-go: load on a dedicated node only if kick stays hundreds and p99 does not explode.

If any of those fail, we stay on the lab. We do not "ship prod" anyway.

## Week 1 — same VM, make the number boring

```bash
sed -i 's/\r$//' hack/*.sh hack/*.py
make check && make go && make scheduler
bash hack/lab-local.sh
bash hack/lab-local.sh
bash hack/lab-two-latency.sh
RUNS=3 DUR=30s bash hack/lab-soak.sh
```

Keep `out/*/uname.txt`, JSON, `counters.txt`.

## Week 2 — Kubernetes on that same node

```bash
sudo make install
bash hack/lab-k8s.sh
```

k3s or kubelet, one node, no CPU limits on the lab pods. Agent must print real cgroup inodes, not `cgroups=0`.

## Week 3 — harder, still one machine

- Soak again after any scheduler tweak.
- Optional: compare default Linux vs scx_kube only (do not add five policies).
- Write the dedicated-node runbook from what actually happened, not from hope.

## Week 4 — dedicated-node "prod test"

One box whose only job is this experiment. Hours, not 15 seconds. Same counters. If it wedges, reboot that box. Then stop and write what broke.

## Out of scope this month

- Other people's production
- Replacing kube-scheduler or EEVDF
- AI policies
- A Helm product
- "Kubernetes is 68% faster"

## Already true

Linux 7.0 lab: p99 22.4 ms → 7.3 ms once, after two published failures. That is the start, not the finish.
