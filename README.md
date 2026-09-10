# KubeSCX

Kubernetes-aware programmable CPU scheduling with eBPF and Linux `sched_ext`.

Kubernetes knows that a pod is latency-sensitive. Linux schedules threads. KubeSCX connects those two layers: a `sched_ext` scheduler that prefers labeled latency work under CPU contention, plus a node agent that maps Pod labels onto cgroup / TGID BPF maps.

This is an MVP, not a replacement for kube-scheduler, EEVDF, or `sched-ext/scx`. The first question it answers is:

> Can a dumb, explicit policy — latency queue before default queue before background queue — improve tail latency for a labeled workload when the node is busy?

If the answer is no, that is still a result. Record it.

## What this repo contains

| Path | Role |
|------|------|
| `scheduler/scx_kube.bpf.c` | `sched_ext` scheduler: three dispatch queues |
| `cmd/kubescx-agent` | Writes cgroup/TGID classifications into pinned BPF maps |
| `cmd/latency-server`, `cmd/cpu-burn`, `cmd/loadgen` | Mixed-workload benchmark |
| `hack/lab-local.sh` | `make lab-local` — no Kubernetes required |
| `deploy/lab/` | Optional single-node Kubernetes lab |
| `labs/` | Hands-on path from Pod → cgroup → task → scheduler |

## Requirements

The Go tools build on Windows or Linux:

```bash
go test ./...
go build -o bin/loadgen ./cmd/loadgen
```

The scheduler only runs on **Linux 6.13+** with:

- `CONFIG_SCHED_CLASS_EXT=y`
- `CONFIG_DEBUG_INFO_BTF=y`
- clang, libbpf, bpftool, gcc

`sched_ext` is a **system-wide** CPU scheduler. Load it on a VM or lab node, not on a laptop you cannot afford to stall. The kernel watchdog (`timeout_ms = 10000`) should fall back if the BPF scheduler wedges.

```bash
make check          # Linux
make scheduler
make lab-local      # contention experiment, prints a p99 table
```

On Ubuntu/Debian see `hack/bootstrap-ubuntu.sh`.

## How the policy works

Unclassified tasks (sshd, kubelet, the agent itself) go to the **default** queue. Only workloads you label become latency or background.

```
payment-api   label scheduling.ebpf.io/class=latency      → DSQ 0 (always first)
unlabeled     (host services, kubelet)                    → DSQ 1
batch-job     label scheduling.ebpf.io/class=background   → DSQ 2 (only if 0 and 1 are empty)
```

The agent does not guess. It writes maps:

- `--tgid 1201:latency` for the local lab
- `--from-json` / `--in-cluster` using pod UID → cgroup inode for Kubernetes

Pinned maps live at `/sys/fs/bpf/kubescx`.

## Teaching and advocacy

The Community & Advocacy half of this project is a small docs site, not a product landing page:

| Page | Purpose |
|------|---------|
| [Explain KubeSCX](docs/explain.md) | One-minute pitch and what not to claim |
| [Teaching path](docs/teach/index.md) | Four lessons: Pod → eBPF → lab → counters |
| [First P99 result](docs/blog/first-p99-result.md) | Blog post from the real 68% table and two failures |
| [Advocacy kit](docs/advocacy.md) | Where to post, talk outline, fellowship-shaped metrics |

Preview locally:

```bash
pip install mkdocs-material
mkdocs serve
```

GitHub Pages deploys from `mkdocs.yml` on push to `main` (enable Pages → GitHub Actions in repo settings). After that the public URL is `https://vi-shub.github.io/KubeSCX/`.

## Kubernetes lab (single node)

## Kubernetes lab (single node)

1. Linux node with `sched_ext`, k3s or kubelet installed.
2. `make scheduler go && sudo make install` (binaries at `/opt/kubescx`).
3. `sudo /opt/kubescx/scx_kube` on the node.
4. `kubectl apply -f deploy/lab`
5. `hack/sync-classes.sh` or let the DaemonSet agent poll the API.
6. `kubectl delete job loadgen -n kubescx-lab --ignore-not-found`
7. `kubectl apply -f deploy/lab/05-loadgen.yaml` and read the job logs.

Pods use `hostPath: /opt/kubescx` so you do not need a container registry.

## What this is not

- Not an observability product
- Not an AI scheduler
- Not a kube-scheduler replacement
- Not five scheduling policies at once

Next experiments (not in this MVP): runtime-adaptive phases, SLO proximity, upstreaming a cleaned scheduler into `sched-ext/scx`.

## License

- `scheduler/` (BPF + C loader): GPL-2.0 (required for `sched_ext` struct_ops)
- remaining Go tools and docs: Apache-2.0
