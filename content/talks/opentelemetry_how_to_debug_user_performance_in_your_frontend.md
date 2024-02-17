---
title: "OpenTelemetry: How to debug user performance in your frontend"
date: 2022-04-27T10:09:14+02:00
draft: false
type: post
tags:
  - talk
  - opentelemetry
  - observability
  - react
  - feature flags
  - unleash
  - frontend
---

In this talk,
which builds up on my previous talk and example of [OpenTelemetry: from Frontend to Backend](../opentelemetry_from_frontend_to_backend)

I give an overview of what OpenTelemetry (OTeL) is and how it can be leveraged to debug frontend performance.
This is achieved
by leveraging only OpenSource components such as [OpenTelemetry](https://opentelemetry.io/) and [Unleash](https://www.getunleash.io/).
The example consists of multiple microservices which are deployed in a Kubernetes cluster.

{{< gslides src="<https://docs.google.com/presentation/d/1w1VhfGQPgCAPoT2VSB6KZlXZOXa_m5p8R-xzOzzL3hM/embed?start=false&loop=false&delayms=3000>" >}}

Repository: <https://github.com/secustor/opentelemetry-meetup>

## Components

### Unleash

[Unleash](https://www.getunleash.io/) is an open source feature flag service.
[In the example](https://github.com/secustor/opentelemetry-meetup/tree/master/deploy/unleash) it is used
to dynamically control which users are traced with which level.
