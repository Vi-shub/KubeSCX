# KubeSCX

**Kubernetes knows workload intent. Linux schedules tasks. eBPF can connect them.**

KubeSCX is a small open-source experiment: a `sched_ext` CPU scheduler that prefers labeled latency-sensitive work when a node is busy, plus labs that teach cloud-native engineers how programmable Linux scheduling works.

It is not a product, not an observability dashboard, and not a replacement for kube-scheduler.

## The question

> Can Kubernetes-style workload class (latency vs background) plus a BPF scheduler improve tail latency under CPU contention — and can we teach that path without requiring a kernel career first?

## One measured result

Linux 7.0, same node, 15 seconds, latency HTTP handler vs a CPU burner:

| scheduler | p99 | rps |
|-----------|-----|-----|
| default Linux | 22.4 ms | 1409 |
| scx_kube | **7.3 ms** | **2388** |

About a **68% p99 cut** on this workload. Two earlier policies made p99 *worse*. Those failures are part of the teaching, not something to hide.

[Read the writeup](blog/first-p99-result.md) · [Run the lab](teach/03-run-the-lab.md) · [How to explain it](explain.md)

## Who this is for

- Kubernetes / platform engineers who treat the Linux scheduler as a black box
- People learning eBPF who are tired of “yet another packet counter”
- Anyone who wants a *reproducible* sched_ext experiment, not a slide deck

## What you will learn

1. A Pod is not what the CPU scheduler sees — [cgroup and task](teach/01-pod-to-task.md)
2. Why this has to be eBPF / `sched_ext`, not a Prometheus controller — [lesson 2](teach/02-ebpf-sched-ext.md)
3. How to load `scx_kube` on a VM and not wedge your laptop — [lesson 3](teach/03-run-the-lab.md)
4. How to read enqueue/dispatch counters when the result looks cursed — [lesson 4](teach/04-read-counters.md)

## Safety

`scx_kube` replaces the CPU scheduler for the **whole machine** while it is loaded. Use a VM. Ctrl-C unloads it. The kernel watchdog should fall back if it wedges.

Code: [github.com/Vi-shub/KubeSCX](https://github.com/Vi-shub/KubeSCX)
