//go:build linux

package bpfmap

import (
	"fmt"
	"path/filepath"

	"github.com/cilium/ebpf"

	"kubescx/internal/classid"
)

type classValue struct {
	Class  uint32
	Weight uint32
}

type Maps struct {
	cgroup *ebpf.Map
	tgid   *ebpf.Map
}

func Open(pinDir string) (*Maps, error) {
	cg, err := ebpf.LoadPinnedMap(filepath.Join(pinDir, classid.MapCgroup), nil)
	if err != nil {
		return nil, fmt.Errorf("open %s (is scx_kube running?): %w", classid.MapCgroup, err)
	}
	tg, err := ebpf.LoadPinnedMap(filepath.Join(pinDir, classid.MapTGID), nil)
	if err != nil {
		cg.Close()
		return nil, fmt.Errorf("open %s (is scx_kube running?): %w", classid.MapTGID, err)
	}
	return &Maps{cgroup: cg, tgid: tg}, nil
}

func (m *Maps) Close() {
	if m.cgroup != nil {
		m.cgroup.Close()
	}
	if m.tgid != nil {
		m.tgid.Close()
	}
}

func (m *Maps) PutCgroup(id uint64, info classid.Info) error {
	return m.cgroup.Put(id, classValue{Class: info.Class, Weight: info.Weight})
}

func (m *Maps) PutTGID(tgid uint32, info classid.Info) error {
	return m.tgid.Put(tgid, classValue{Class: info.Class, Weight: info.Weight})
}

func (m *Maps) DeleteTGID(tgid uint32) error {
	return m.tgid.Delete(tgid)
}
