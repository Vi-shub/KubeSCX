# Community

KubeSCX is a public `sched_ext` experiment. The useful outcome is not a star count. It is that someone else can load the scheduler, read the counters, and disagree with the table.

Site: [https://vi-shub.github.io/KubeSCX/](https://vi-shub.github.io/KubeSCX/).
Code: [github.com/Vi-shub/KubeSCX](https://github.com/Vi-shub/KubeSCX).

## What this project is for

Platform engineers already label Pods. Linux still schedules threads. This repo maps an explicit class (`latency`, `default`, `background`) onto CPU dispatch and measures tail latency under contention.

Teaching starts from a Pod, then a `sched_ext` load, then a p99 table. Maps and kfuncs come after you can explain the counters.

## Talk (12 minutes)

Designed for a CNCF / college / eBPF meetup. Live `lab-local` if the VM works. Otherwise the table and the two failed policies.

| Time | Content |
|------|---------|
| 1 min | Kubernetes QoS vs Linux tasks. kube-scheduler places Pods. It does not pick the next thread. |
| 2 min | What `sched_ext` is. Skip the verifier. Watchdog and Ctrl-C matter more. |
| 2 min | Policy: three FIFO queues. Unlabeled work stays **default**, ahead of background. |
| 3 min | Two failures: idle LOCAL bypass (p99 ~699 ms), then `SCX_KICK_PREEMPT` on every enqueue (~6.4M kicks / 15s, p99 ~423 ms). |
| 2 min | Winning table on Linux 7.0 and the counter line (`kick=528`, not millions). |
| 2 min | How to run `bash hack/lab-local.sh` on Linux 6.13+. Ask the room to file a loss. |

Leave time for: *does this starve kubelet?* No. kubelet is unlabeled, so it uses the default queue.

## Claims this project does not make

- Kubernetes is 68% faster.
- We replaced the Linux scheduler, EEVDF, or kube-scheduler.
- Production-ready for other people's clusters.
- A graph without kernel version, the lab command, and the two failed policies.

Say the result in one piece: on Linux 7.0, in this mixed latency-vs-burner lab, scx_kube cut p99 from 22 ms to 7 ms and raised throughput. Two earlier policies made p99 much worse. One workload, not a cluster SLO.

## How to report a result

Open a [lab result issue](https://github.com/Vi-shub/KubeSCX/issues/new?template=lab-result.yml). Include:

1. Kernel version
2. The compare table from `hack/lab-local.sh`
3. The last `enq` / `disp` / `kick` line from `scx_kube`

A worse p99 is a valid report. A missing table is not.

## Where to discuss

1. GitHub issues and the lab template (reproducible first).
2. sched-ext / eBPF technical channels with the command, the counters, and the negative results.
3. A meetup once you can run lesson 3, or can explain why your kernel cannot.

Social posts come after a result someone else can reproduce. Advocacy that the scx community cannot rerun is marketing.

## What would count as progress

- Lab tables from other machines (wins and losses)
- PRs that make the harness clearer, not a new policy family
- A workshop where someone else drives the VM
- A second workload or a k3s node run, when the first lab is boringly repeatable

Do not treat GitHub stars as impact.
