# Contributing

Thank you for trying KubeSCX. This project is an experiment and a teaching lab. Small, reproducible changes beat large rewrites.

## First rule

Load `scx_kube` only on a VM. It replaces the CPU scheduler for the whole machine.

## Good first work

- Docs and lab wording (especially ARM, distro packages, missing `bpftool`)
- Extra recorded `lab-local` tables (include kernel version and the counter line)
- Run `hack/lab-two-latency.sh` and paste both servers' p99
- Agent dry-run output that is easier to read
- Tests for label parsing and cgroup UID matching
- A second synthetic workload (not five new policies)

## Not first work

- AI schedulers
- Replacing kube-scheduler
- Energy or NUMA policies
- "Make it production ready"

## How to run tests (any OS)

```bash
go test ./...
```

## How to run the scheduler (Linux 6.12+)

```bash
make check
make scheduler
sed -i 's/\r$//' hack/*.sh
bash hack/lab-local.sh
```

If scripts came from Windows, always strip CR. `hack/*.sh` must use Unix line endings.

## Docs site

```bash
pip install mkdocs-material
mkdocs serve
```

## Pull requests

1. One concern per PR.
2. If you change the scheduler, paste a before/after `lab-local` table or explain why the harness could not run.
3. Do not claim speedups without kernel version and counters.
4. BPF / C loader stays GPL-2.0. Go tools stay Apache-2.0.

## Code of conduct

Be precise. Negative results are welcome. Mocking people who cannot load `sched_ext` is not.
