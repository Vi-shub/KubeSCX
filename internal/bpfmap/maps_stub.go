//go:build !linux

package bpfmap

import (
	"fmt"

	"kubescx/internal/classid"
)

type Maps struct{}

func Open(pinDir string) (*Maps, error) {
	return nil, fmt.Errorf("BPF maps are Linux-only (pin dir %s)", pinDir)
}

func (m *Maps) Close() {}

func (m *Maps) PutCgroup(id uint64, info classid.Info) error {
	return fmt.Errorf("BPF maps are Linux-only")
}

func (m *Maps) PutTGID(tgid uint32, info classid.Info) error {
	return fmt.Errorf("BPF maps are Linux-only")
}

func (m *Maps) DeleteTGID(tgid uint32) error {
	return fmt.Errorf("BPF maps are Linux-only")
}
