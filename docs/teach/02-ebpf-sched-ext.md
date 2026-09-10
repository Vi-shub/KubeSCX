# Lesson 2 — Why eBPF and sched_ext

People hear “eBPF” and think Cilium, Tetragon, or a flame graph. KubeSCX uses eBPF for a different job: **the scheduling decision itself**.

## Two shapes of eBPF

```
Observability:  kernel event → BPF → number → dashboard
Optimization:   kernel event → BPF → pick the next task
```

KubeSCX is the second. A controller that reads Prometheus and patches a CRD is too slow and too far from the runqueue. Wakeups happen in microseconds. `sched_ext` runs in that path.

## What sched_ext is

Linux 6.12+ can load a BPF program that implements `struct sched_ext_ops` (enqueue, dispatch, tick, …). The kernel keeps the safety net: a watchdog, fallback to the default class when you Ctrl-C or when the program wedges.

KubeSCX does **not** replace `sched_ext`. It is one policy on top of it.

```
eBPF → sched_ext → scx_kube (three FIFO queues)
```

## Why not “just nice userspace priorities”

`nice`, cgroup CPU shares, and CPU Manager isolation are real tools. They are also coarse. This project exists to ask whether **explicit workload class at dispatch time** beats the default scheduler under *mixed* load — and to make that question runnable by people who do not patch the kernel.

## Checkpoint

You should be able to answer: *What happens if scx_kube crashes?* (The kernel should drop back to the default scheduler. That is why we still use a VM.)
