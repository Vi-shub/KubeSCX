# KubeSCX

Kubernetes-aware programmable CPU scheduling with eBPF and Linux `sched_ext`.

Kubernetes knows a pod is latency-sensitive. Linux schedules threads. KubeSCX connects those layers: a `sched_ext` scheduler that prefers labeled latency work under CPU contention, plus labs that teach how that works.

This is an MVP. It does not replace kube-scheduler, EEVDF, or `sched-ext/scx`.

> Can a simple policy (latency queue, then default, then background) improve tail latency for a labeled workload when the node is busy?

If the answer is no, that is still a result. Record it. The working plan is [PLAN.md](PLAN.md).

On Linux 7.0 this harness cut **p99 from 22.4 ms to 7.3 ms** (about 68%) and raised rps from 1409 to 2388. Two earlier policies made p99 worse. Details: [docs/results.md](docs/results.md).

## What this repo contains

| Path | Role |
|------|------|
| `scheduler/scx_kube.bpf.c` | `sched_ext` scheduler: three FIFO queues |
| `cmd/kubescx-agent` | Pod labels or TGIDs into pinned BPF maps |
| `cmd/latency-server`, `cmd/cpu-burn`, `cmd/loadgen` | Mixed-workload benchmark |
| `hack/lab-local.sh` | Contention lab, no Kubernetes required |
| `deploy/lab/` | Optional single-node Kubernetes lab |
| `docs/` | Teaching site: [vi-shub.github.io/KubeSCX](https://vi-shub.github.io/KubeSCX/) |

## Requirements

Go tools build on Windows or Linux:

```bash
go test ./...
go build -o bin/loadgen ./cmd/loadgen
```

The scheduler only runs on **Linux 6.13+** with `CONFIG_SCHED_CLASS_EXT`, BTF, clang, libbpf, bpftool, gcc.

`sched_ext` is system-wide. Use a VM. Ctrl-C unloads it. Watchdog timeout is 10s.

```bash
make check
make scheduler
sed -i 's/\r$//' hack/*.sh
bash hack/lab-local.sh
# optional: two latency servers sharing the queue
bash hack/lab-two-latency.sh
```

Ubuntu packages: `hack/bootstrap-ubuntu.sh`.

## How the policy works

Unclassified tasks (sshd, kubelet, the agent) go to **default**. Only labeled workloads become latency or background.

```
payment-api   scheduling.ebpf.io/class=latency       DSQ 0 (first)
unlabeled     host services                          DSQ 1
batch-job     scheduling.ebpf.io/class=background    DSQ 2 (last)
```

Maps: `--tgid 1201:latency` for the local lab, or Pod UID to cgroup inode on Kubernetes. Pins live at `/sys/fs/bpf/kubescx`.

## Docs

Teaching site: **[https://vi-shub.github.io/KubeSCX/](https://vi-shub.github.io/KubeSCX/)**

| Page | Purpose |
|------|---------|
| [Plan](https://vi-shub.github.io/KubeSCX/plan/) | What is done, what to run next, what is out of scope |
| [Explain](https://vi-shub.github.io/KubeSCX/explain/) | One-minute pitch and what not to claim |
| [Architecture](https://vi-shub.github.io/KubeSCX/architecture/) | Queues, agent, BPF ops |
| [Results](https://vi-shub.github.io/KubeSCX/results/) | Recorded table and failed policies |
| [Teaching path](https://vi-shub.github.io/KubeSCX/teach/) | Four lessons |
| [Blog](https://vi-shub.github.io/KubeSCX/blog/first-p99-result/) | First public writeup |
| [Community](https://vi-shub.github.io/KubeSCX/advocacy/) | Talk outline and how to report a result |
| [CONTRIBUTING](CONTRIBUTING.md) / [ROADMAP](ROADMAP.md) | How others help |

```bash
pip install mkdocs-material
mkdocs serve
```

## Dedicated node

Labs are one-shot. To leave `scx_kube` running like a service on a throwaway VM: [docs/dedicated-node.md](docs/dedicated-node.md) / `bash hack/install-node.sh`. This is still not a production cluster.

## Kubernetes lab (single node)

1. Linux node with `sched_ext`. k3s or kubelet.
2. `make scheduler go && sudo make install` (binaries at `/opt/kubescx`)
3. `sudo /opt/kubescx/scx_kube` on the node
4. `kubectl apply -f deploy/lab`
5. `hack/sync-classes.sh` or the DaemonSet agent
6. Apply `deploy/lab/05-loadgen.yaml` and read Job logs

Pods use `hostPath: /opt/kubescx` so you do not need a registry.

## What this is not

- Not an observability product
- Not an AI scheduler
- Not a kube-scheduler replacement
- Not five policies at once

## License

- `scheduler/` (BPF and C loader): GPL-2.0
- remaining Go tools and docs: Apache-2.0
