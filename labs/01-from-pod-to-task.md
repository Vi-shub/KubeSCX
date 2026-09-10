# Lab 1: From Pod to cgroup to Linux task

The Linux scheduler does not see Pods. It sees tasks (threads) and cgroups. This lab makes that mapping visible without loading a custom scheduler.

## 1. A process is a task

On Linux:

```bash
ps -o pid,tgid,comm,cgroup
```

`pid` is the thread. `tgid` is the thread-group / process id. `scx_kube` can classify either a TGID (local lab) or a cgroup id (Kubernetes).

## 2. A container is a cgroup

```bash
cat /proc/self/cgroup
ls /sys/fs/cgroup
stat -c '%i %n' /sys/fs/cgroup
```

cgroup v2 ids are directory inodes. That integer is the BPF map key in `cgroup_class`.

## 3. A Pod is a tree of cgroups

On a node with Kubernetes:

```bash
# pick a pod
kubectl get pod -n kubescx-lab payment-api-xxxx -o jsonpath='{.metadata.uid}{"\n"}'

# systemd + containerd typically looks like:
# /sys/fs/cgroup/kubepods.slice/kubepods-burstable.slice/kubepods-burstable-pod<uid_with_underscores>.slice/
```

`kubescx-agent` walks `/sys/fs/cgroup` for that UID and writes **every nested directory inode** into the map, so pause + app containers are both classified.

## 4. Dry-run the agent (no BPF required)

From a machine with `kubectl` and node filesystem access:

```bash
kubectl get pods -A -o json | go run ./cmd/kubescx-agent --dry-run --from-json -
```

`--dry-run` prints pod → class → cgroup ids and does not need `scx_kube` loaded. On Windows this command cannot see Linux cgroup inodes; run it on the node.

## Why this matters

If this mapping is wrong, the scheduler is guessing. The MVP keeps classification in userspace on purpose: the BPF program only reads a hash map.
