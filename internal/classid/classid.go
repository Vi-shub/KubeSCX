package classid

// Keep in sync with include/kubescx.h
const (
	Default    = 0
	Latency    = 1
	Background = 2

	WeightLatency    = 500
	WeightDefault    = 100
	WeightBackground = 25

	PinDir       = "/sys/fs/bpf/kubescx"
	MapCgroup    = "cgroup_class"
	MapTGID      = "tgid_class"
	LabelClass   = "scheduling.ebpf.io/class"
)

type Info struct {
	Class  uint32
	Weight uint32
}

func Parse(s string) (Info, bool) {
	switch s {
	case "latency", "latency-sensitive", "lat":
		return Info{Class: Latency, Weight: WeightLatency}, true
	case "background", "batch", "bg":
		return Info{Class: Background, Weight: WeightBackground}, true
	case "default", "def", "":
		return Info{Class: Default, Weight: WeightDefault}, true
	default:
		return Info{}, false
	}
}

func Name(class uint32) string {
	switch class {
	case Latency:
		return "latency"
	case Background:
		return "background"
	default:
		return "default"
	}
}
