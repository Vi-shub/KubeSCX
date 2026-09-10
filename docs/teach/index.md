# Teaching path

Four lessons. The goal is not “become a kernel developer.” It is: a Kubernetes engineer can load a BPF scheduler, classify two processes, and explain the p99 table.

| # | Lesson | You leave able to |
|---|--------|-------------------|
| 1 | [Pod → cgroup → task](01-pod-to-task.md) | Say why kube-scheduler is the wrong layer for this problem |
| 2 | [eBPF and sched_ext](02-ebpf-sched-ext.md) | Say why a Prometheus loop is too slow and unsafe here |
| 3 | [Run the lab](03-run-the-lab.md) | Produce a baseline vs scx_kube table on a VM |
| 4 | [Read the counters](04-read-counters.md) | Debug a *worse* p99 instead of shrugging |

Hands-on files live in the repo under [`labs/`](https://github.com/Vi-shub/KubeSCX/tree/main/labs) and [`hack/lab-local.sh`](https://github.com/Vi-shub/KubeSCX/blob/main/hack/lab-local.sh).

## What we are not teaching yet

Writing a scheduler from zero, verifier puzzles, energy-aware policies, AI policies. Those are later. If a newcomer cannot finish lesson 3, the course failed — not they failed.
