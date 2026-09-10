#!/usr/bin/env bash
set -euo pipefail

echo "KubeSCX environment check"
echo "  kernel: $(uname -s) $(uname -r)"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "FAIL: scx_kube needs Linux. Build Go tools here; run the lab on a Linux VM."
  exit 1
fi

if [[ ! -e /sys/kernel/btf/vmlinux ]]; then
  echo "FAIL: /sys/kernel/btf/vmlinux missing (CONFIG_DEBUG_INFO_BTF)"
  exit 1
fi
echo "OK  BTF: /sys/kernel/btf/vmlinux"

if [[ -d /sys/kernel/sched_ext ]]; then
  echo "OK  sched_ext sysfs: /sys/kernel/sched_ext"
  if [[ -f /sys/kernel/sched_ext/state ]]; then
    echo "    state=$(cat /sys/kernel/sched_ext/state)"
  fi
else
  echo "FAIL: /sys/kernel/sched_ext missing. Need Linux 6.12+ with CONFIG_SCHED_CLASS_EXT=y"
  echo "      Fedora 41+, Ubuntu with a 6.13+ kernel, or a custom kernel are typical."
  exit 1
fi

need() {
  if command -v "$1" >/dev/null 2>&1; then
    echo "OK  $1: $(command -v "$1")"
  else
    echo "FAIL: missing $1"
    return 1
  fi
}

ok=0
need clang || ok=1
need bpftool || ok=1
need gcc || ok=1
need go || true

if [[ $ok -ne 0 ]]; then
  echo "Install: sudo apt install clang llvm libbpf-dev libelf-dev zlib1g-dev linux-tools-generic gcc make"
  echo "         or: sudo dnf install clang llvm libbpf-devel elfutils-libelf-devel bpftool gcc make"
  exit 1
fi

echo "ready to: make scheduler && make lab-local"
