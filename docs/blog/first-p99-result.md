# First result: a 68% p99 cut, after two losses

*11 September 2026. Kernel Linux 7.0.0-30-generic. Same-node lab, not a cluster.*

KubeSCX asks whether a `sched_ext` policy that knows “this process is latency-sensitive” can beat the default Linux CPU scheduler when a node is busy.

The answer on this machine, for this harness, was yes, but only after two policies made things much worse. That order is the story.

## The harness

A small HTTP server burns 800 µs of CPU per request. A `cpu-burn` process saturates the machine. `loadgen` measures p50/p95/p99. Then we load `scx_kube`, classify the server as `latency` and the burner as `background`, and measure again.

Unlabeled tasks stay in a **default** queue (sshd, the load generator, kubelet if you were on k8s). Unknown work is never treated as batch. That choice is load-bearing.

## Loss 1: idle fast-path

`select_cpu` inserted *any* waking task onto `SCX_DSQ_LOCAL` if a CPU looked idle. The burner does that all the time, so it bypassed the background queue and sat on every core. Latency work waited in its own DSQ.

p99 went from about 23 ms to about 699 ms. Throughput collapsed. The scheduler was attached; the policy was just wrong.

## Loss 2: preempt on every enqueue

We “fixed” that by kicking `SCX_KICK_PREEMPT` whenever a latency task was enqueued. Go servers park and wake threads constantly. The counter line was:

```
enq lat=6417095  kick=6417095
```

About 430,000 preemptions per second. p95 improved. p99 went to ~423 ms. The body of the distribution got better; the tail was a self-preemption storm.

## Win: FIFO classes, no enqueue kick, tick yield

Background tasks may not take the idle LOCAL path. Queues are FIFO: latency, then default, then background. If latency work is waiting, `tick` ends the current non-latency slice. We do not kick on every enqueue.

```
scheduler          p50_ms   p95_ms   p99_ms  p99.9_ms      rps
default              4.08    15.08    22.44     34.83   1409.2
scx_kube             3.02     5.92     7.27     10.50   2387.5
p99 change vs default: +67.6%
```

```
enq lat=11376 def=15456 bg=142  disp lat=11376 def=15455 bg=139  idle=38 kick=528
```

Enqueue matches dispatch. Kick is hundreds, not millions. Background still runs a little. p99 dropped about 68% and requests/second went up.

## What this does not mean

It does not mean Kubernetes is 68% faster. It does not mean EEVDF is “bad.” It does not mean you should load this on a production node.

It means workload class at dispatch time can matter under contention. The experiment is reproducible. Counters will tell you when you have a kick storm instead of a win.

Reproduce: Linux 6.13+ VM, `make scheduler`, `bash hack/lab-local.sh`. If your table loses, file it. Negative results are the curriculum.
