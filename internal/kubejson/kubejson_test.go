package kubejson

import (
	"strings"
	"testing"
)

func TestParseLabeledPods(t *testing.T) {
	raw := `{
  "items": [
    {
      "metadata": {
        "name": "payment-api",
        "namespace": "kubescx-lab",
        "uid": "11111111-1111-1111-1111-111111111111",
        "labels": {"scheduling.ebpf.io/class": "latency"}
      },
      "spec": {"nodeName": "node-a"}
    },
    {
      "metadata": {
        "name": "batch",
        "namespace": "kubescx-lab",
        "uid": "22222222-2222-2222-2222-222222222222",
        "labels": {"scheduling.ebpf.io/class": "background"}
      },
      "spec": {"nodeName": "node-a"}
    }
  ]
}`
	pods, err := Parse(strings.NewReader(raw))
	if err != nil {
		t.Fatal(err)
	}
	if len(pods) != 2 {
		t.Fatalf("len=%d", len(pods))
	}
	if !pods[0].Labeled || pods[0].Class.Class != 1 {
		t.Fatalf("payment: %+v", pods[0])
	}
	if !pods[1].Labeled || pods[1].Class.Class != 2 {
		t.Fatalf("batch: %+v", pods[1])
	}
}

func TestParseUnlabeledAndUnknown(t *testing.T) {
	raw := `{
  "items": [
    {
      "metadata": {
        "name": "sshd",
        "namespace": "kube-system",
        "uid": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
      },
      "spec": {"nodeName": "node-a"}
    },
    {
      "metadata": {
        "name": "weird",
        "namespace": "default",
        "uid": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
        "labels": {"scheduling.ebpf.io/class": "turbo"}
      },
      "spec": {"nodeName": "node-b"}
    }
  ]
}`
	pods, err := Parse(strings.NewReader(raw))
	if err != nil {
		t.Fatal(err)
	}
	if len(pods) != 2 {
		t.Fatalf("len=%d", len(pods))
	}
	if pods[0].Labeled || pods[0].Label != "" {
		t.Fatalf("unlabeled: %+v", pods[0])
	}
	if pods[1].Labeled || pods[1].Label != "turbo" {
		t.Fatalf("unknown class should not be labeled: %+v", pods[1])
	}
	if pods[1].NodeName != "node-b" {
		t.Fatalf("node: %s", pods[1].NodeName)
	}
}
