---
title: "OpenTelemetry: from Frontend to Backend"
date: 2021-11-09T10:00:22+02:00
draft: false
type: post
tags:
  - talk
  - opentelemetry
  - observability
  - kafka
  - kubernetes
project_url: https://github.com/secustor/opentelemetry-meetup
---

In this talk, I give an overview of what OpenTelemetry (OTeL) is and what it can help you to achieve.
The example consists of multiple microservices which are deployed in a Kubernetes cluster fully traced with OTeL.
The traced components are:

- React frontend
- Kubernetes Ingress Controller
- API backend
- Kafka
- Asynchronous processing microservice

{{< gslides src="https://docs.google.com/presentation/d/1jPDH8Csv-Qle7Z-P7rFJgjOsBpgKeehPhjFPqTRET1Y/embed?start=false&loop=false&delayms=3000" >}}

Repository: <https://github.com/secustor/opentelemetry-meetup>

## Components

### Snapshot

[Snapshot](https://github.com/Yog9/SnapShot) is a React photo gallery to showcase capabilities.
In this example,
OpenTelemetry tracing capabilities have been added
to allow an easy way to demonstrate the capture of user input and API call tracing.

![snapshot-demo-picture](./images/snapshot.webp)

Code: <https://github.com/secustor/opentelemetry-meetup/tree/master/apps/snapshot>

#### Report

The `report` consists of the Kafka producer
which accepts API calls from [Snapshot](#snapshot) and writes the request content on a Kafka topic.
From this Kafka topic, the consumer reads the received messages asynchronously and prints them.

Code: <https://github.com/secustor/opentelemetry-meetup/tree/master/apps/report>

#### OpenTelemetry

The example makes use of the [OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector-contrib/) and [SDKs](https://opentelemetry.io/ecosystem/registry/?component=core)
for collecting, transforming as well as loading and for instrumentation respectively.

#### Observability Stack

The Stack below is used to store Observability signals ( Traces, Metrics, Logs ) and graph them:

- [Grafana](https://github.com/grafana/grafana/) ( Dashboarding )
- [Tempo](https://github.com/grafana/tempo) ( Traces )
- [Loki](https://github.com/grafana/loki) ( Logs)
- [Prometheus](https://github.com/prometheus/prometheus) ( Metrics )
