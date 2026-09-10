#!/usr/bin/env bash
set -euo pipefail
echo "Ubuntu/Debian-ish packages for building scx_kube:"
echo "  sudo apt-get update"
echo "  sudo apt-get install -y clang llvm libbpf-dev libelf-dev zlib1g-dev gcc make linux-tools-generic golang-go bpftool python3"
echo
echo "Fedora:"
echo "  sudo dnf install -y clang llvm libbpf-devel elfutils-libelf-devel zlib-devel gcc make bpftool golang python3"
echo
echo "Then: make check && make scheduler && make lab-local"
