package kubeapi

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"time"
)

const saDir = "/var/run/secrets/kubernetes.io/serviceaccount"

type Client struct {
	http     *http.Client
	host     string
	token    string
	nodeName string
}

func InCluster(nodeName string) (*Client, error) {
	token, err := os.ReadFile(filepath.Join(saDir, "token"))
	if err != nil {
		return nil, fmt.Errorf("in-cluster token: %w", err)
	}
	ca, err := os.ReadFile(filepath.Join(saDir, "ca.crt"))
	if err != nil {
		return nil, fmt.Errorf("in-cluster CA: %w", err)
	}
	pool := x509.NewCertPool()
	if !pool.AppendCertsFromPEM(ca) {
		return nil, fmt.Errorf("parse service account CA")
	}
	host := os.Getenv("KUBERNETES_SERVICE_HOST")
	port := os.Getenv("KUBERNETES_SERVICE_PORT")
	if host == "" {
		host = "kubernetes.default.svc"
	}
	if port == "" {
		port = "443"
	}
	return &Client{
		http: &http.Client{
			Timeout: 15 * time.Second,
			Transport: &http.Transport{
				TLSClientConfig: &tls.Config{RootCAs: pool, MinVersion: tls.VersionTLS12},
			},
		},
		host:     "https://" + host + ":" + port,
		token:    string(token),
		nodeName: nodeName,
	}, nil
}

func (c *Client) ListPods() (*http.Response, error) {
	u, err := url.Parse(c.host + "/api/v1/pods")
	if err != nil {
		return nil, err
	}
	q := u.Query()
	if c.nodeName != "" {
		q.Set("fieldSelector", "spec.nodeName="+c.nodeName)
	}
	u.RawQuery = q.Encode()
	req, err := http.NewRequest(http.MethodGet, u.String(), nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+c.token)
	req.Header.Set("Accept", "application/json")
	return c.http.Do(req)
}

func Available() bool {
	_, err := os.Stat(filepath.Join(saDir, "token"))
	return err == nil
}
