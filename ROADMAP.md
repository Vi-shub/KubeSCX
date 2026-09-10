# Roadmap

KubeSCX stays small until the lab is boringly reproducible.

## Done

- Working `scx_kube` FIFO policy (no LOCAL bypass for background, no enqueue preempt storm)
- Recorded Linux 7.0 p99 result (~68% on this harness), including two published failures
- Four lessons, first writeup, public teaching site
- Agent: TGID and cgroup labels

## Next

- Repeat `lab-local` on 6.13 and 7.x, three runs each
- Second workload (two latency processes, or mixed I/O)
- k3s single-node: Pod label to cgroup map, same benchmark
- Compare against `scx_simple` as a second baseline, not only default Linux

## Later (only if the lab still holds)

- Optional experimental CRD (not a promise)
- Runtime-adaptive phases
- Upstream a tiny scx doc or example if maintainers want it
- Energy or locality policies: out of scope until then

## Explicitly out of scope

- Replacing kube-scheduler or EEVDF
- AI-written schedulers
- A hosted SaaS
- Guaranteeing 68% anywhere else
