package classid

import "testing"

func TestParse(t *testing.T) {
	info, ok := Parse("latency")
	if !ok || info.Class != Latency || info.Weight != WeightLatency {
		t.Fatalf("latency: %+v ok=%v", info, ok)
	}
	info, ok = Parse("batch")
	if !ok || info.Class != Background {
		t.Fatalf("batch: %+v", info)
	}
	if _, ok := Parse("nope"); ok {
		t.Fatal("expected unknown class to fail")
	}
	info, ok = Parse("default")
	if !ok || info.Class != Default {
		t.Fatalf("default: %+v ok=%v", info, ok)
	}
	info, ok = Parse("")
	if !ok || info.Class != Default {
		t.Fatalf("empty: %+v ok=%v", info, ok)
	}
}
