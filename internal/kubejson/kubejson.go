package kubejson

import (
	"encoding/json"
	"io"

	"kubescx/internal/classid"
)

type Pod struct {
	Name      string
	Namespace string
	UID       string
	NodeName  string
	Class     classid.Info
	Labeled   bool
}

type list struct {
	Items []struct {
		Metadata struct {
			Name      string            `json:"name"`
			Namespace string            `json:"namespace"`
			UID       string            `json:"uid"`
			Labels    map[string]string `json:"labels"`
		} `json:"metadata"`
		Spec struct {
			NodeName string `json:"nodeName"`
		} `json:"spec"`
	} `json:"items"`
}

func Parse(r io.Reader) ([]Pod, error) {
	var raw list
	if err := json.NewDecoder(r).Decode(&raw); err != nil {
		return nil, err
	}
	out := make([]Pod, 0, len(raw.Items))
	for _, item := range raw.Items {
		p := Pod{
			Name:      item.Metadata.Name,
			Namespace: item.Metadata.Namespace,
			UID:       item.Metadata.UID,
			NodeName:  item.Spec.NodeName,
		}
		if item.Metadata.Labels != nil {
			if s, ok := item.Metadata.Labels[classid.LabelClass]; ok {
				if info, ok := classid.Parse(s); ok {
					p.Class = info
					p.Labeled = true
				}
			}
		}
		out = append(out, p)
	}
	return out, nil
}
