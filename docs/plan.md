# Plan

Kubernetes can mark a Pod as latency-sensitive. Linux schedules threads. KubeSCX is a `sched_ext` policy plus a lab that maps that class onto CPU dispatch and measures p99 under contention.

One policy. Three FIFO queues: **latency**, then **default**, then **background**. Unlabeled work stays default. This does not replace kube-scheduler or EEVDF.

The repo copy of this page is [PLAN.md](https://github.com/Vi-shub/KubeSCX/blob/main/PLAN.md).

## Next VM session

Use a Linux 6.13+ VM with `sched_ext` (the recorded run was Linux 7.0). Copy the latest tree onto the VM first. Do not run `scp C:\...` from Linux.

```bash
cd /root/KubeSCX
sed -i 's/\r$//' hack/*.sh hack/*.py
make check
make go
make scheduler
```

Then run both labs. Stay at the machine. `scx_kube` is system-wide. Ctrl-C unloads it.

| Order | Command | What you are checking |
|-------|---------|------------------------|
| 1 | `bash hack/lab-local.sh` | Repeat the first result. Output in `out/lab-*`. |
| 2 | `bash hack/lab-local.sh` | Second repeat. Do not edit the scheduler between 1 and 2. |
| 3 | `bash hack/lab-two-latency.sh` | Two latency servers, one burner, load on both at once. |

Optional if those finished and the VM is still healthy:

```bash
DUR=30s CONC=8 bash hack/lab-local.sh
```

### What to keep

From each `out/lab-*` and `out/lab-two-latency-*` folder: `uname.txt`, the JSON files, and `counters.txt`.

A worse p99 is still a result. A missing table means the run did not finish.

### How to read the run

**lab-local:** both rows printed; `enq` ≈ `disp`; `kick` hundreds not millions. The 22.4 ms → 7.3 ms table was one run. Record the new numbers.

**lab-two-latency:** four rows (default-a/b, scx-a/b). `enq lat` should move. Close p99 on a vs b means they shared the latency queue. A large gap means FIFO burstiness. Either is publishable.

If `make check` fails, stop. WSL and Docker will not work.

## Already done

| Piece | Status |
|-------|--------|
| `scx_kube` three FIFO DSQs | Working. Background must not take `SCX_DSQ_LOCAL`. No kick on every enqueue. Tick yields if latency work is waiting. |
| First lab | Linux 7.0: p99 22.4 ms → 7.3 ms (~68%), rps 1409 → 2388. Two failed policies documented. |
| Agent | TGID and cgroup maps. Warns if a labeled Pod has no cgroup inode. |
| Teaching site | This site. |
| Second lab script | `hack/lab-two-latency.sh`. No recorded table until it is run. |

## Main line of work

Stay on one question until the answer is boring:

> Does workload class at dispatch time improve tail latency when the node is busy, and can someone else reproduce that (including the losses)?

1. Repeat the first lab until three runs on this kernel exist.
2. Second workload on the same node: two latency processes.
3. Kubernetes path only after that: Pod label to cgroup inode, same loadgen.
4. Later baseline: `scx_simple` as well as default Linux.
5. Teaching stays attached to the lab. New writeup only after a new table.

## Later

- Fairness counters for background
- k3s single-node, same p99 harness
- Optional CRD only if the node path is real
- Upstream a small scx example if maintainers want it

## Out of scope

- Replacing kube-scheduler or EEVDF
- AI schedulers
- Production SLOs on other clusters
- "Kubernetes is 68% faster"

## Safety

`scx_kube` replaces the CPU scheduler for the whole machine while it is loaded. VM only. If it wedges, wait ~10s for the watchdog or reboot the VM.
