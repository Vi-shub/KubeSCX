# KubeSCX

Kubernetes knows workload intent. Linux schedules tasks. eBPF can connect them at CPU time.

KubeSCX is an open-source **sched_ext** scheduler plus a teaching lab. You label latency-sensitive work. Under CPU contention, that work is allowed to run before background burners. Cloud-native engineers can run the experiment without patching the kernel.

It is not a product, not a dashboard, and not a replacement for kube-scheduler.

!!! success "Measured on Linux 7.0"
    Same node, 15s, 8 clients, 800µs CPU per request vs a full-machine burner.

    **p99 22.4 ms → 7.3 ms (about 68% lower). Throughput 1409 → 2388 rps.**

    Two earlier policies made p99 *worse*. Those runs are documented.

[Run the lab](teach/03-run-the-lab.md){ .md-button .md-button--primary }
[Read the result](blog/first-p99-result.md){ .md-button }
[Architecture](architecture.md){ .md-button }

## The question

Can a workload class (latency vs background) plus a BPF scheduler improve tail latency when the node is busy, and can we teach that path without a kernel career first?

## Who this is for

- Kubernetes and platform engineers who treat the Linux scheduler as a black box
- People learning eBPF who want a decision in the kernel, not another packet counter
- Anyone who wants a reproducible `sched_ext` experiment, including the failures

## What you will learn

1. A Pod is not what the CPU scheduler sees. Start with [cgroup and task](teach/01-pod-to-task.md).
2. Why this is eBPF / `sched_ext`, not a Prometheus controller. See [lesson 2](teach/02-ebpf-sched-ext.md).
3. How to load `scx_kube` on a VM. See [lesson 3](teach/03-run-the-lab.md).
4. How to read enqueue, dispatch, and kick counters. See [lesson 4](teach/04-read-counters.md).

## Safety

`scx_kube` replaces the CPU scheduler for the **whole machine** while it is loaded. Use a VM. Ctrl-C unloads it. The kernel watchdog should fall back if it wedges.

Code: [github.com/Vi-shub/KubeSCX](https://github.com/Vi-shub/KubeSCX)
