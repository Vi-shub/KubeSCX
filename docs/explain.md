# Explain KubeSCX in plain language

Use this when someone asks “what are you building?” Keep it short. Do not start with eBPF.

## The one-minute version

Kubernetes lets you say “this Pod is important.” The Linux CPU scheduler does not speak Pod. It speaks threads, wakeups, and runqueues.

So on a busy node, a payment API and a batch job can look the same to Linux even when Kubernetes knows they are not.

KubeSCX is a BPF program that *is* the CPU scheduler (`sched_ext`) plus a tiny userspace agent. You label a process or Pod `latency` or `background`. Under contention, latency work is allowed to run first.

We measured that on a real kernel. We also measured two ways to get it badly wrong.

## The whiteboard

```
Kubernetes          KubeSCX              Linux
---------           -------              -----
Pod / QoS    -->    class map     -->    sched_ext
"latency"           cgroup / TGID        three queues:
"background"        BPF hash maps          latency
                                           default
                                           background
```

Unlabeled tasks (sshd, kubelet, the load generator) stay **default**. That is deliberate. If unknown work goes to background, you can stall the machine.

## Analogies that work

- **Not** “we rewrote Kubernetes scheduling.” kube-scheduler still places Pods on nodes. This is *inside* one node, at the CPU.
- **Like** a HOV lane: latency traffic gets the lane when the highway is jammed. When the road is empty, everyone just drives.
- **Unlike** a dashboard: eBPF here *changes what runs*, it does not only export metrics.

## What to say about the 68%

Say this sentence, whole:

> On Linux 7.0, a mixed latency-vs-burner lab, scx_kube cut p99 from 22 ms to 7 ms and raised throughput. Two earlier policies made p99 much worse. This is one workload, not “Kubernetes is 68% faster.”

If you drop the middle sentences, you are advocating badly.

## What this is not

| People hear | You say |
|-------------|---------|
| New Cilium | Different layer. Networking vs CPU scheduling. |
| AI scheduler | No models. Explicit classes. |
| Replaces kube-scheduler | Complementary. Placement vs run time. |
| Production-ready | Experimental. VM only. Watchdog fallback. |

## Three audiences

**Platform engineer:** “Labels you already have (priority, QoS) never reach the CPU scheduler. We are probing that gap with sched_ext.”

**eBPF beginner:** “Most tutorials attach a probe and print a number. This one *is* the scheduler. You can break it, measure it, and unload it.”

**Kernel person:** “Three FIFO DSQs, no LOCAL fast-path for background, no preempt-on-enqueue. Tick yields if the latency DSQ is non-empty. Happy to be wrong; here is the harness.”
