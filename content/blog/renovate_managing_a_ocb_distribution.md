---
title: "Renovate: Keep your OpenTelemetry Collector up to date!"
date: 2024-01-07T00:05:24+02:00
type: post
showToc: true
tags:
  - blog
  - renovate
  - RenovateBot
  - dependency-management
  - opentelemetry
  - opentelemetry-collector
---

With the widespread adoption of [OpenTelemetry](https://opentelemetry.io/) as standard in the Observability ecosystem,
the more I see the [OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector/tree/main) deployed at customers. 

A nice subproject here is the [OpenTelemetry Collector Builder (OCB)](https://github.com/open-telemetry/opentelemetry-collector/tree/main/cmd/builder)
which allows to easily create your custom distribution of the Collector.   
Some notable distributions here are: 
- [AWS](https://github.com/aws-observability/aws-otel-collector)
- [RedHat](https://github.com/os-observability/redhat-opentelemetry-collector)
- [SumoLogic](https://github.com/SumoLogic/sumologic-otel-collector)
- others can be found [here](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/distributions.yaml)

These custom distributions can be used to the minimum size for your specific use case or a custom module
written by your own.
For example, to implement a complex filter logic or support an internal API. 

Such a custom distro starts mostly simply,
tough with time more and more modules will be added, 
and sooner than later you will have to invest some time to keep the builder config update to date.   
Here comes the new [`ocb`](https://docs.renovatebot.com/modules/manager/ocb/) manager for RenovateBot into play.   
If enabled,
it allows updating the OCB config files with the current versions
and simultaneously bumping the version of your collector distribution.

We will use this `builder-config.yaml` named build config file for our custom distribution:
```yaml title="builder-config.yaml"
dist:
  name: otelcol-custom
  description: Local OpenTelemetry Collector binary
  module: github.com/open-telemetry/opentelemetry-collector
  otelcol_version: 0.86.0
  version: 1.0.0
  output_path: /tmp/dist
exporters:
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/exporter/awss3exporter v0.86.0
  - gomod: go.opentelemetry.io/collector/exporter/debugexporter v0.86.0
receivers:
  - gomod: go.opentelemetry.io/collector/receiver/otlpreceiver v0.86.0
processors:
  - gomod: go.opentelemetry.io/collector/processor/batchprocessor v0.86.0
```
We define our OpenTelemetryCollector version we want to use via `otelcol_version`

`version` defines the version of our custom distribution.

Modules such as `exporters`,
`connectors`, `receivers` and `processors` are list of Go modules which are packaged in our distribution.

## How to update all of this?
As there is no convention of how the builder configs are named,
Renovate has not any file pattern added by default to look for. 
Because of this fact we have to add an additional [`fileMatch`](https://docs.renovatebot.com/configuration-options/#filematch) pattern for our `ocb` manager. 
```json title="renovate.json"
{
  "ocb": {
    "fileMatch": [
      "builder-config\\.ya?ml$"
    ]
  }
}
```
Here we instruct Renovate
to look files named `builder-config.yml` or `builder-config.yaml` in any location in your repository.

When Renovate runs against your repository, you will get a number of PRs which will update the different components.

## There are too many!
Now you may want to group all PRs if they are coming from one of the upstream repositories.
You can achieve this with [`packageRules`](https://docs.renovatebot.com/configuration-options/#packagerules) and 
the [`groupName`](https://docs.renovatebot.com/configuration-options/#groupname) attribute.

```json title="renovate.json"
{
  "ocb": {
    "fileMatch": [
      "builder-config\\.ya?ml$"
    ]
  },
  "packageRules": [
    {
      "matchSourceUrls": [
        "https://github.com/open-telemetry/opentelemetry-collector",
        "https://github.com/open-telemetry/opentelemetry-collector-contrib"
      ],
      "groupName": "upstream dependencies"
    }
  ]
}
```
You can also use [`matchDepTypes`](https://docs.renovatebot.com/configuration-options/#matchdeptypes)
with the `depTypes` provided by `ocb` such as `collector` and `extensions`.

## Can we automate that?
With all these new PRs, we have still to bump the version before merging, tough this can be automated too. 
This is achieved using the [`bumpVersion`](https://docs.renovatebot.com/configuration-options/#bumpversion) option,
which sets up Renovate to increase the `version` field with a semver level. 

```json title="renovate.json"
{
  "bumpVersion": "minor",
  "ocb": {
    "fileMatch": [
      "builder-config\\.ya?ml$"
    ]
  }
}
```

And this is it.
You can find this setup in this example repo: https://github.com/secustor/ocb-renovate.   

I hope you like this newest addition to Renovate, and it will reduce the load overhead the same as it has done for me.
