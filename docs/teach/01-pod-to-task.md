# Lesson 1: From Pod to Linux task

The Linux CPU scheduler never sees a Pod. It sees **tasks** (threads) and **cgroups**. If you skip this, KubeSCX looks like magic labels.

## Why Kubernetes is not enough

kube-scheduler chooses a *node*. After the Pod is running, Linux decides *which thread runs on which CPU in the next few milliseconds*. Priority, QoS, and `requests.cpu` influence cgroups and CFS bandwidth. They do not give you a programmable “this is a latency class” policy inside `sched_ext`.

## Three identities

| Layer | Name | Example |
|-------|------|---------|
| Kubernetes | Pod UID, labels | `scheduling.ebpf.io/class=latency` |
| cgroup v2 | directory inode | `stat -c %i /sys/fs/cgroup/...` |
| Linux | `tgid` / `pid` | `ps -o pid,tgid,comm` |

KubeSCX’s agent maps the first onto the second (or, in the local lab, onto `tgid`). The BPF scheduler only looks up a hash map. It does not parse YAML.

## Try it (no custom scheduler)

On Linux:

```bash
ps -o pid,tgid,comm,cgroup
cat /proc/self/cgroup
stat -c '%i %n' /sys/fs/cgroup
```

On a node with Kubernetes, the Pod UID shows up in the cgroup path (dashes become underscores under systemd slices). Full walkthrough: [labs/01-from-pod-to-task.md](https://github.com/Vi-shub/KubeSCX/blob/main/labs/01-from-pod-to-task.md).

## Checkpoint

You should be able to answer: *If the agent writes the wrong inode, what does the scheduler do?* (It treats the workload as **default**. Unlabeled is never background.)
