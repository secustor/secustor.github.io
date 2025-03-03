---
title: "K8s monitoring v2: Why are there no logs?"
date: 2025-03-19T00:05:24+02:00
type: post
showToc: true
tags:
  - blog
  - homelab
  - alloy
  - grafana
---

I have introduced Grafanas ["K8s Monitoring helm chart v2"](https://github.com/grafana/k8s-monitoring-helm/tree/main/charts/k8s-monitoring) recently into my homelab, but I had a bad awakening when trying to debug an issue with my ingress and the logs were not showing up in Grafana.
In the end, it has been a [layer 8 issue](https://en.wikipedia.org/wiki/Layer_8), so behind the keyboard 😅, but I wanted to share the solution with you.

TLDR: You need to set the `securityContext` for the `alloy-logs` to allow privileged access to the containers.
This is to allow the `alloy` container to assume the `root` user and collect logs host.

## Symptoms

The following log entries are shown in the `alloy` logs:

```text
ts=2025-03-01T23:55:08.729084207Z level=info msg="skipping update of position for a file which does not currently exist" component_path=/pod_logs.feature component_id=loki.source.file.pod_logs component=tailer path=/var/log/pods/kube-system_kube-router-bjndh_653bf29a-28c8-4dca-8357-bb0b8f65133f/install-cniconf/0.log
```

Basically, Alloy is not able to write the index files it uses to keep track of the already ingested log lines.

## Solution

The solution is to set the `securityContext` for the `alloy-logs` to allow privileged access to the containers.
This is to allow the `alloy` container to assume the `root` user and collect logs from the `/var/log/*` directory on the host, which is documented in the [Grafana Alloy Helm chart values file](https://github.com/grafana/alloy/tree/main/operations/helm/charts/alloy#collecting-logs-from-other-containers)

```yaml
alloy-logs:
  enabled: true
  alloy:
    # we need privileged access to collect logs from other containers
    securityContext:
      allowPrivilegeEscalation: true
      privileged: true
      runAsUser: 0

podLogs:
  enabled: true
nodeLogs:
  enabled: true
```
