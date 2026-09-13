# Lesson 3: Run the lab

This is the whole course’s practical exam. You need a **Linux 6.12+ VM** with `CONFIG_SCHED_CLASS_EXT`. WSL2 5.15 will not work. Docker will not work. A cloud VM with kernel 7.x does.

## Install and check

```bash
git clone https://github.com/Vi-shub/KubeSCX.git
cd KubeSCX
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y clang llvm libbpf-dev libelf-dev zlib1g-dev gcc make \
  linux-tools-generic golang-go python3 bpftool || true

sed -i 's/\r$//' hack/*.sh
make check
make scheduler
```

`make check` must show `OK sched_ext`. If it does not, stop. You cannot fake this with containers.

## Produce the table

```bash
bash hack/lab-local.sh
```

The script measures default Linux, loads `scx_kube`, classifies the latency server and the CPU burner, measures again, and prints p50/p95/p99 and rps. JSON and counters land in `out/lab-*` so they survive after the processes stop.

Optional second experiment (two latency servers, one burner):

```bash
bash hack/lab-two-latency.sh
```

Safety: this attaches a system-wide scheduler. Use a throwaway VM. Ctrl-C unloads it.

Details and the recorded 68% table: [labs/03-benchmark-p99.md](https://github.com/Vi-shub/KubeSCX/blob/main/labs/03-benchmark-p99.md).

## Checkpoint

Paste your table somewhere (issue, gist, blog). A *worse* p99 is a valid lab report. A missing table means you did not finish the lesson.
