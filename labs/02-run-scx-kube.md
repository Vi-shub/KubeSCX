# Lab 2 — Load scx_kube

`scx_kube` replaces the CPU scheduler for the whole machine while it is attached. Use a VM.

## 1. Check the kernel

```bash
make check
```

You want `/sys/kernel/sched_ext` and `/sys/kernel/btf/vmlinux`.

## 2. Build and load

```bash
make scheduler
sudo ./bin/scx_kube
```

The process prints enqueue/dispatch counters once a second:

```
enq lat=… def=… bg=…  disp lat=… def=… bg=…
```

Leave it running. Ctrl-C unloads the scheduler and Linux returns to the default class.

## 3. Classify two processes

In another terminal:

```bash
make go
./bin/latency-server &  echo $!
./bin/cpu-burn &        echo $!

sudo ./bin/kubescx-agent --tgid <latency-pid>:latency --tgid <burn-pid>:background
```

If classification worked, `enq lat=` and `enq bg=` should start moving while you generate load:

```bash
./bin/loadgen -url http://127.0.0.1:8080/work -c 8 -d 10s
```

## Safety

If the machine feels wedged, wait for the 10s `sched_ext` watchdog or reboot the VM. Do not debug this on a shared production node.
