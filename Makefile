SHELL := /bin/bash
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

GO ?= go
CLANG ?= clang
BPFTOOL ?= bpftool
CC ?= gcc

ARCH := $(shell uname -m 2>/dev/null | sed -e 's/x86_64/x86/' -e 's/aarch64/arm64/' -e 's/armv7l/arm/' -e 's/ppc64le/powerpc/' -e 's/mips.*/mips/' -e 's/riscv64/riscv/' )
BINDIR ?= $(ROOT)/bin
PREFIX ?= /opt/kubescx

BPF_SRC := $(ROOT)/scheduler/scx_kube.bpf.c
BPF_OBJ := $(ROOT)/scheduler/scx_kube.bpf.o
SKEL := $(ROOT)/scheduler/scx_kube.skel.h
VMLINUX := $(ROOT)/scheduler/vmlinux.h
SCX_BIN := $(BINDIR)/scx_kube

CLANG_BPF_SYS_INCLUDES := $(shell $(CLANG) -v -E - </dev/null 2>&1 | \
	sed -n '/search starts here:/,/End of search list/ { s|^ \(.*\)|-idirafter \1|p }')

BPF_CFLAGS := -g -O2 -Wall -Werror -target bpf -D__TARGET_ARCH_$(ARCH) \
	-I$(ROOT)/include -I$(ROOT)/scheduler -I$(ROOT)/scheduler/include \
	$(CLANG_BPF_SYS_INCLUDES)

.PHONY: help all go scheduler lab lab-local bench check test clean install images

help:
	@echo "KubeSCX"
	@echo "  make go          build Go tools (works on Windows/Linux)"
	@echo "  make scheduler   build scx_kube (Linux 6.13+ with sched_ext)"
	@echo "  make test        run unit tests"
	@echo "  make lab-local   contention lab without Kubernetes"
	@echo "  make bench       run loadgen against :8080"
	@echo "  make check       verify kernel sched_ext support"
	@echo "  make install     copy binaries to $(PREFIX)"

all: go

go:
	mkdir -p $(BINDIR)
	CGO_ENABLED=0 $(GO) build -o $(BINDIR)/latency-server ./cmd/latency-server
	CGO_ENABLED=0 $(GO) build -o $(BINDIR)/cpu-burn ./cmd/cpu-burn
	CGO_ENABLED=0 $(GO) build -o $(BINDIR)/loadgen ./cmd/loadgen
	CGO_ENABLED=0 $(GO) build -o $(BINDIR)/kubescx-agent ./cmd/kubescx-agent

test:
	$(GO) test ./...

$(VMLINUX):
	@if [ ! -e /sys/kernel/btf/vmlinux ]; then \
		echo "missing /sys/kernel/btf/vmlinux — need a BTF-enabled Linux kernel"; \
		exit 1; \
	fi
	$(BPFTOOL) btf dump file /sys/kernel/btf/vmlinux format c > $(VMLINUX)

$(BPF_OBJ): $(BPF_SRC) $(VMLINUX) $(ROOT)/include/kubescx.h $(ROOT)/scheduler/include/scx_kube.bpf.h
	$(CLANG) $(BPF_CFLAGS) -c $(BPF_SRC) -o $(BPF_OBJ)

$(SKEL): $(BPF_OBJ)
	$(BPFTOOL) gen skeleton $(BPF_OBJ) > $(SKEL)

scheduler: $(SKEL)
	mkdir -p $(BINDIR)
	$(CC) -g -O2 -Wall -I$(ROOT)/include -I$(ROOT)/scheduler \
		$(ROOT)/scheduler/scx_kube.c -lbpf -lelf -lz -o $(SCX_BIN)
	@echo "built $(SCX_BIN)"

check:
	@$(ROOT)/hack/check-env.sh

lab-local: go
	@$(ROOT)/hack/lab-local.sh

lab: lab-local

bench: go
	$(BINDIR)/loadgen -url http://127.0.0.1:8080/work -c 8 -d 20s

install: go
	mkdir -p $(PREFIX)
	cp -a $(BINDIR)/. $(PREFIX)/
	@if [ -f $(SCX_BIN) ]; then cp $(SCX_BIN) $(PREFIX)/; fi
	@echo "installed to $(PREFIX)"

clean:
	rm -rf $(BINDIR) $(BPF_OBJ) $(SKEL) $(VMLINUX) $(SCX_BIN)
