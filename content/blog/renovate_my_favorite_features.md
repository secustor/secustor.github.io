---
title: "Renovate: My favorite features"
date: 2023-07-11T14:05:24+02:00
type: post
showToc: true
tags:
  - blog
  - renovate
  - RenovateBot
  - dependency-management
---

In this blog,
we will go through the config
used in the Meetup talk ["Renovate: Let's
upgrade your dependency workflow"](../../talks/renovate_lets_upgrade_your_dependency_workflow)
and I will explain how to implement my favorite features of [Renovate](https://github.com/renovatebot/renovate/).
If you do not know what Renovate is, I highly recommend going through the slides. 

### The basis
First we add a JSON schema reference with the `$schema` key,
which allows editors to fetch the current schema of Renovate config.
This enables intellisense and validation in IDEs.

The second option `extends` is an array of [Presets](https://docs.renovatebot.com/key-concepts/presets/) references.
Presets are used to ship and share common configuration from the Renovate team to the community.
It is also possible to use [presets
to point to configuration files in other repositories](https://docs.renovatebot.com/config-presets/).
This can be used to centrally manage your configuration for a whole organization
or define a common config for a type of repository.

`github>foo/bar:myConfig` will for example load a `json` named `myConfig.json` located in the root of https://github.com/foo/bar
```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:base",
    "github>foo/bar:myConfig"
  ]
}
```

### Vulnerabilities
[`osvVulnerabilityAlerts`](https://docs.renovatebot.com/configuration-options/#osvvulnerabilityalerts)
enables Renovate to lookup dependencies on https://osv.dev to find potential security risks.

[`dependencyDashboardOSVVulnerabilitySummary`](https://docs.renovatebot.com/configuration-options/#dependencydashboardosvvulnerabilitysummary)
controls if and what vulnerabilities should be displayed on the "Dependency Dashboard".
Here we use `all` to display even vulnerabilities for which Renovate already has opened PRs to fix them up.
```json
{
  "osvVulnerabilityAlerts": true,
  "dependencyDashboardOSVVulnerabilitySummary": "all"
}
```

### Labels and Templates
Labels are useful to find quick PRs opened by Renovate.
To enable this Renovate provides to config options
which can be set globally or in the scope of a [packageRule](https://docs.renovatebot.com/configuration-options/#packagerules).

These two are [`labels`](https://docs.renovatebot.com/configuration-options/#labels) and [`addLabels`](https://docs.renovatebot.com/configuration-options/#addlabels).

The first is not merge-able and will therefore be overwritten if set multiple times,
e.g. and in scope a [packageRule](https://docs.renovatebot.com/configuration-options/#packagerules)

The second is additive so if multiple `addLabels` options are defined the values are merged before applying to the PRs.

In the definition of the second label, we see another important feature of Renovate:
[**templating**](https://docs.renovatebot.com/templates/).
These allow defining dynamic values.
In this case, we could define a [packageRule](https://docs.renovatebot.com/configuration-options/#packagerules) for each
[manager](https://docs.renovatebot.com/modules/manager/),
but this way a label is with the manager name is added to every PR created in this repository.
```json
{
  "addLabels": ["renovate","{{{manager}}}"]
}
```

### Package Rules and Replacements
[packageRule](https://docs.renovatebot.com/configuration-options/#packagerules) can be used
to conditionally apply configuration.
This is done by defining a set of match and exclude functions,
these are identifiable by the `match` and `exclude` prefix respectively.

Other options are applied if the rule matches,
e.g. [`groupName`](https://docs.renovatebot.com/configuration-options/#groupname) to group multiple updates together.
`description` is an exception to this rule, it has no effect and is only used to document your rules if JSON is used.

`replacementName` is one of multiple `replacement` options, which allow migration of all matching dependencies to a new one.
In this case we match every Docker reference ( `matchDatasources` )
with the reference to the Renovate Docker image on DockerHub
( `matchPackageNames` ) and then apply the new Docker reference.
This leads to a new replacement PR such as [this one](https://github.com/secustor/renovate-meetup/pull/10).
```json
{
  "packageRules": [
    {
      "description": "Replace Dockerhub with ghcr.io for renovate",
      "matchDatasources": ["docker"],
      "matchPackageNames": ["docker.io/renovate/renovate"],
      "replacementName": "ghcr.io/renovatebot/renovate"
    }
  ]
}
```

### Regex Manager
[RegexManagers](https://docs.renovatebot.com/configuration-options/#regexmanagers) allows updating versions
are not natively supported by Renovate.
This could be for example variables which reference dependencies,
parts of documentation referring to Docker images or simply ecosystems which Renovate does not support yet.

The first manager looks at the `README.md` in the root of the repository
and then uses the regex defined in `matchStrings` to extract the
`depName` ( which is in this case the Docker image) and the `currentValue` ( the Docker image tag e.g. `v1.3.0` ).
Finally, we define the datasource `docker` ( which uses DockerHub by default) to look up the found Docker image.

The second manager is a more complex example,
it makes use of a common pattern in which a comment is added before a dependency you want to update.
Consider the following Dockerfile:
```Dockerfile
# renovate: datasource=github-releases depName=aquasecurity/trivy extractVersion=true
ARG TRIVY_VERSION=0.40.0
RUN wget -c https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64Bit.tar.gz -O - | \
        tar -xzC /usr/local/bin trivy
```
This will match the string    
`# renovate: datasource=github-releases depName=aquasecurity/trivy extractVersion=true \nARG TRIVY_VERSION=0.40.0`    
and extract `github-releases` as datasource, `aquasecurity/trivy`
as dependency name, `0.40.0`
as value.
If the user defines a different versioning system than the default one
( `semver` )
or an `extractVersion` block with `true` will activate in the pattern the removal of leading `v`s in versions of GitHub releases.
The result is visible on [this PR](https://github.com/secustor/renovate-meetup/pull/14).
```json
{
  "regexManagers": [
    {
      "fileMatch": ["^README.md$"],
      "matchStrings": ["(?<depName>[\\w/\\.]+):(?<currentValue>[^\\s]+)"],
      "datasourceTemplate": "docker"
    },
    {
      "fileMatch": ["(^|/)Dockerfile$"],
      "matchStrings": [
        "renovate: datasource=(?<datasource>.*?) depName=(?<depName>\\S*)( versioning=(?<versioning>.*?))?( extractVersion=(?<extractVersion>.*?))?\\nARG .*?_VERSION=(?<currentValue>.*)\\s"
      ],
      "versioningTemplate": "{{#if versioning}}{{{versioning}}}{{else}}semver{{/if}}",
      "extractVersionTemplate": "{{#if (equals extractVersion 'true')}}^v(?<version>\\S+){{/if}}"
    }
  ]
}
```

### The complete config
Now we can combine all parts and get following `renovate.json`
```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:base"
  ],
  "osvVulnerabilityAlerts": true,
  "dependencyDashboardOSVVulnerabilitySummary": "all",
  "addLabels": ["renovate","{{{manager}}}"],
  "packageRules": [
    {
      "description": "Replace Dockerhub with ghcr.io for renovate",
      "matchDatasources": ["docker"],
      "matchPackageNames": ["docker.io/renovate/renovate"],
      "replacementName": "ghcr.io/renovatebot/renovate"
    }
  ],
  "regexManagers": [
    {
      "fileMatch": ["^README.md$"],
      "matchStrings": ["(?<depName>[\\w/\\.]+):(?<currentValue>[^\\s]+)"],
      "datasourceTemplate": "docker"
    },
    {
      "fileMatch": ["(^|/)Dockerfile$"],
      "matchStrings": [
        "renovate: datasource=(?<datasource>.*?) depName=(?<depName>\\S*)( versioning=(?<versioning>.*?))?( extractVersion=(?<extractVersion>.*?))?\\nARG .*?_VERSION=(?<currentValue>.*)\\s"
      ],
      "versioningTemplate": "{{#if versioning}}{{{versioning}}}{{else}}semver{{/if}}",
      "extractVersionTemplate": "{{#if (equals extractVersion 'true')}}^v(?<version>\\S+){{/if}}"
    }
  ]
}
```

Repository: https://github.com/secustor/renovate-meetup
