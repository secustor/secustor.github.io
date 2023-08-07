---
title: "Renovate: No Datasource? No problem!"
date: 2023-08-07T00:05:24+02:00
type: post
showToc: true
tags:
  - blog
  - renovate
  - RenovateBot
  - dependency-management
  - custom-datasource
---

In this blog entry,
I would like you
to show a new feature of [Renovate](https://github.com/renovatebot/renovate/), which makes it even more flexible when dealing with non-standard dependencies: [`customDatasources`](https://docs.renovatebot.com/configuration-options/#customdatasources).

<!--more-->

RenovateBot provides a [lot of datasources](https://docs.renovatebot.com/modules/datasource/) which covers most use cases. 
If a dependency uses Docker or GitHub releases the respective datasources can be used,
but sometimes projects are not developed in public, are mixing different release channels on GitHub
or are using an own API.
That makes it nearly impossible for the RenovateBot team to support all the different project and tools out there.


Introducing :rocket:
[`customDatasources`](https://docs.renovatebot.com/configuration-options/#customdatasources) :rocket:  
This feature allows you to define configuration-based datasources,
which rely heavily in their core on [JSONata](https://jsonata.org/), 
which is an JSON transformation engine much like JQ.
These rules allow creating transformation rules for JSON documents, which are used to change API results into an understandable format for Renovate.

But how does this work in practice? Let's go through this step by step. 

## The basics
If you are familiar with how RenovateBot works, you can skip this section, tough it can still hold some valuable information for experienced users.

- A [`Manager`](https://docs.renovatebot.com/modules/manager/) defines the files which should be scanned and provide functionality to extract dependencies from these files
- A [`Datasource`](https://docs.renovatebot.com/modules/datasource/) on the other hand defines how to find available versions of dependencies. Usually `datasources` query registries or APIs to retrieve the versions.
- A [`Versioning`](https://docs.renovatebot.com/modules/versioning/) defines a version pattern. Example for this are `semver`, if releases follow strict semantic versioning or `pep440` in the case of Python version ranges.

Updating a dependency follows these steps: 
- Clone repository
- Find files using the `fileMatch` parameter of `managers`
- Extract dependencies based on the `manager` logic
- The `manager` returns the detected dependencies, which contain the `currentVersion`, an optional `registryURL`, a `packageName` and/or `depName`, a datasource as well as a `versioning`
- Fetch releases from `datasource` based on the `packageName`. If the `datasource` supports custom registries the `registryURL` will be used instead of a by the `datasource` predefined URL.
- Then the provided `versioning` is used to compare releases and find fitting ones dependent on the provided configuration. 

The results of each stage can be overwritten using [`packageRules`](https://docs.renovatebot.com/configuration-options/#packagerules).

## The example
To walk you through the setup, we use a Dockerfile as an example.
In this case, the Consul CLI is installed from the download repositories of Hashicorp. 

```dockerfile
FROM alpine:3.18.2@sha256:25fad2a32ad1f6f510e528448ae1ec69a28ef81916a004d3629874104f8a7f70

ENV CONSUL_VERSION=1.15.0
RUN wget -qO- https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip | bsdtar -xvf- -O /usr/local/bin/
```

All version references are already extracted to a single environment variable to ease updating it. 

## Extracting a custom dependency
Usually if you use RenovateBot you use one the provided managers such as `maven`, `terraform` and `npm`. 
These will extract dependencies and define the required fields such as `packageName`. 
See [the basics](#the-basics) for more examples what kind of fields are returned from the `manager`.

If you plan to use a `customDatasource` you will most of the time make use of the `regex` manager. 
This special manager hands off most of the logic to user-defined regexes, this allows extracting any kind dependency as long as it is defined in a text file.

In our case we create this `regex` manager:
```json
{
  "regexManagers": [
    {
      "fileMatch": ["Dockerfile$"],
      "datasourceTemplate": "custom.hashicorp",
      "matchStrings": [
        "#\\s*renovate:\\s*(datasource=(?<datasource>.*?) )?depName=(?<depName>.*?)( versioning=(?<versioning>.*?))?\\s*.*?_VERSION=(?<currentValue>.*)"
      ]
    }
  ]
}
```
Let's go through the different options set here, for all available options see the [`regexManager` docs](https://docs.renovatebot.com/modules/manager/regex/).

`fileMatch` is set to match every file that ends in `Dockerfile`.

`datasourceTemplate` template used for datasource.
This will be used if no `datasource` match group could be extracted from `matchStrings`.

`matchStrings` is a list regexes which are matched against the content of the matched files. 
All occurrences will be extracted and processed.
The regex in this example looks for a comment which is lead by
`renovate` and contains at least a definition of `depName` for looking up a packages in a datasource.
Optionally a `datasource` and a `versioning` can be provided too.
If no versioning has been defined `semver-coerced` will be used.
The line after comment has to contain `_VERSION=` followed by the current version. 
If you have additional formats you can add additional `matchStrings` or separate `regexManagers`. 

For testing these regexes, I highly recommend using an online regex tester such as https://regex101.com.
Do **NOT** forget to escape your backslashes!  
To see how this works with our example, go to https://regex101.com/r/sw7act/1.

With the added comment, we get the following content:
```dockerfile
FROM alpine:3.18.2@sha256:25fad2a32ad1f6f510e528448ae1ec69a28ef81916a004d3629874104f8a7f70

# renovate: depName=consul
ENV CONSUL_VERSION=1.15.0
RUN wget -qO- https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip | bsdtar -xvf- -O /usr/local/bin/
```

## How to define a custom datasource
`customDatasources` can be defined in the global configuration available for self-hosted instances or in the normal repository configs.
The `customDatasources` field contains name and config pairs.
The name has to be a unique string, to reference the datasource prefix it simply with `custom.`.
 
```json
{
  "customDatasources": {
    "hashicorp": {
      "defaultRegistryUrlTemplate": "https://api.releases.hashicorp.com/v1/releases/{{packageName}}",
      "format": "json",
      "transformTemplates": [
        "{ \"releases\": $[license_class=\"oss\"].{\"version\": version,\"releaseTimestamp\": timestamp_created,\"changelogUrl\": url_changelog,\"sourceUrl\": url_source_repository},\"homepage\": $[license_class=\"oss\"][0].url_project_website}"
      ]
    }
  }
}
```

We make use of three options here:

`defaultRegistryUrlTemplate`: The result of this field is used as `registryUrl` if there is none provided by the manager. 
Further, this is a RenovateBot template that allows to dynamically generate strings.
In that case we template the `packageName` into the `registryUrl`.

`format`: defines which format the API uses. `json` is the default, therefore, it is omitted in the other examples.

`transformTemplates`: Is a list of [JSONata](https://jsonata.org/) transformations. 
These rules are evaluated in series, so you can split the logic in multiple steps.
This can massively reduce the logic.
As with `defaultRegistryUrlTemplate` you can template in variables.
See the [`custom` datasource docs](https://docs.renovatebot.com/modules/datasource/custom/#usage) for more infos.

## Writing Jsonata rules
If your API is not directly exposing the expected RenovateBot format (see [this doc](https://docs.renovatebot.com/modules/datasource/custom/#usage)), which will be the case for most public APIs. 
For this, we will use the [JSONata Playground](https://try.jsonata.org/), which allows us to test our rules directly in the browser. 

### The setup
The end result we are looking for is this JSON: 
```json
{
  "releases": [
    {
      "version": "1.16.0",
      "releaseTimestamp": "2023-06-26T23:10:57.602Z",
      "changelogUrl": "https://github.com/hashicorp/consul/blob/release/1.16.0/CHANGELOG.md",
      "sourceUrl": "https://github.com/hashicorp/consul"
    },
    {
      "version": "1.15.4",
      "releaseTimestamp": "2023-06-26T19:14:58.684Z",
      "changelogUrl": "https://github.com/hashicorp/consul/blob/release/1.15.4/CHANGELOG.md",
      "sourceUrl": "https://github.com/hashicorp/consul"
    },
    ["..."]
  ],
  "homepage": "https://www.consul.io"
}
```

and the (shortened) response we are getting from the Hashicorp API endpoint
(`https://api.releases.hashicorp.com/v1/releases/consul?license_class=oss`) is: 
```json
[
  {
    "builds": ["..."],
    "is_prerelease": false,
    "license_class": "oss",
    "name": "consul",
    "status": {
      "state": "supported",
      "timestamp_updated": "2023-06-26T23:10:57.602Z"
    },
    "timestamp_created": "2023-06-26T23:10:57.602Z",
    "timestamp_updated": "2023-06-26T23:10:57.602Z",
    "url_changelog": "https://github.com/hashicorp/consul/blob/release/1.16.0/CHANGELOG.md",
    "url_docker_registry_dockerhub": "https://hub.docker.com/r/hashicorp/consul",
    "url_docker_registry_ecr": "https://gallery.ecr.aws/hashicorp/consul",
    "url_license": "https://github.com/hashicorp/consul/blob/main/LICENSE",
    "url_project_website": "https://www.consul.io",
    "url_release_notes": "https://www.consul.io/docs/release-notes",
    "url_shasums": "https://releases.hashicorp.com/consul/1.16.0/consul_1.16.0_SHA256SUMS",
    "url_shasums_signatures": [
      "https://releases.hashicorp.com/consul/1.16.0/consul_1.16.0_SHA256SUMS.sig",
      "https://releases.hashicorp.com/consul/1.16.0/consul_1.16.0_SHA256SUMS.72D7468F.sig"
    ],
    "url_source_repository": "https://github.com/hashicorp/consul",
    "version": "1.16.0"
  },
  {
    "builds": ["..."],
    "is_prerelease": false,
    "license_class": "oss",
    "name": "consul",
    "status": {
      "state": "supported",
      "timestamp_updated": "2023-06-26T19:14:58.684Z"
    },
    "timestamp_created": "2023-06-26T19:14:58.684Z",
    "timestamp_updated": "2023-06-26T19:14:58.684Z",
    "url_changelog": "https://github.com/hashicorp/consul/blob/release/1.15.4/CHANGELOG.md",
    "url_docker_registry_dockerhub": "https://hub.docker.com/r/hashicorp/consul",
    "url_docker_registry_ecr": "https://gallery.ecr.aws/hashicorp/consul",
    "url_license": "https://github.com/hashicorp/consul/blob/main/LICENSE",
    "url_project_website": "https://www.consul.io",
    "url_release_notes": "https://www.consul.io/docs/release-notes",
    "url_shasums": "https://releases.hashicorp.com/consul/1.15.4/consul_1.15.4_SHA256SUMS",
    "url_shasums_signatures": [
      "https://releases.hashicorp.com/consul/1.15.4/consul_1.15.4_SHA256SUMS.sig",
      "https://releases.hashicorp.com/consul/1.15.4/consul_1.15.4_SHA256SUMS.72D7468F.sig"
    ],
    "url_source_repository": "https://github.com/hashicorp/consul",
    "version": "1.15.4"
  },
  ["..."]
]
```

### The first steps with JSONata
First, we are going to create the root structure of the result:
```jsonata
{ 
    "releases": [],
    "homepage": ""
}
```
This will result in the same output as the JSONata rule as everything is static. 

The next step is to set the homepage by simply referencing the first element of the input JSON.
```jsonata
{ 
    "releases": [],
    "homepage": $[0].url_project_website
}
```
`$` means here the root of the input object.   
`[0]` access the first element.   
`.url_project_website` use the value of `url_project_website` field.

Which results in this JSON: 
```json
{
  "releases": [],
  "homepage": "https://www.consul.io"
}
```

### Create for each object a new release
Now to the more interesting part, mapping elements of the API result to a new array under `releases`.
If we had to simply copy all objects, it would be easy.
Simply copy it using `$` and we are done, tough we need to translate the field names too. 

Therefore,
we have to use the [JSONata object constructor](https://docs.jsonata.org/construction#object-constructors),
which allows use to loop over the input array and then to reference each field we want to copy to our result.
```jsonata
{ 
    "releases": $.{
        "version": version,
        "releaseTimestamp": timestamp_created,
        "changelogUrl": url_changelog, 
        "sourceUrl": url_source_repository 
    },
    "homepage": $[0].url_project_website
}
```
The field names are the names we want on the target objects, 
and the "field values" of our JSONata rule are the names found in our input. 
That's it. 

This will pretty much look like what we want:

```json
{
  "releases": [
    {
      "version": "1.16.0+ent.fips1402",
      "releaseTimestamp": "2023-06-26T23:11:52.759Z",
      "changelogUrl": "https://github.com/hashicorp/consul-enterprise/blob/release/1.16.0/CHANGELOG.md"
    },
    {
      "version": "1.16.0+ent",
      "releaseTimestamp": "2023-06-26T23:11:45.416Z",
      "changelogUrl": "https://github.com/hashicorp/consul-enterprise/blob/release/1.16.0/CHANGELOG.md"
    },
    {
      "version": "1.16.0",
      "releaseTimestamp": "2023-06-26T23:10:57.602Z",
      "changelogUrl": "https://github.com/hashicorp/consul/blob/release/1.16.0/CHANGELOG.md",
      "sourceUrl": "https://github.com/hashicorp/consul"
    },
    ["..."]
  ],
  "homepage": "https://www.consul.io/docs/enterprise"
}
```
Note that the enterprise versions do not have `sourceUrl` fields
and because we are picking the first input object we are getting now the enterprise link for `homepage`.

Tough because we do not use the enterprise version, we probably want to filter them out. 
This is what we are going to do in the next section.

### Let's skip these
To skip these during creation, we add a [predicate](https://docs.jsonata.org/predicate#predicates).
```jsonata
{ 
    "releases": $[license_class="oss"].{
        "version": version,
        "releaseTimestamp": timestamp_created,
        "changelogUrl": url_changelog, 
        "sourceUrl": url_source_repository 
    },
    "homepage": $[license_class="oss"][0].url_project_website
}
```
`[license_class="oss"]` translates to that the input object has to have a field named `license_class` with the value `oss`.

Which brings us to the final output we have been looking for: 
```json
{
  "releases": [
    {
      "version": "1.16.0",
      "releaseTimestamp": "2023-06-26T23:10:57.602Z",
      "changelogUrl": "https://github.com/hashicorp/consul/blob/release/1.16.0/CHANGELOG.md",
      "sourceUrl": "https://github.com/hashicorp/consul"
    },
    {
      "version": "1.15.4",
      "releaseTimestamp": "2023-06-26T19:14:58.684Z",
      "changelogUrl": "https://github.com/hashicorp/consul/blob/release/1.15.4/CHANGELOG.md",
      "sourceUrl": "https://github.com/hashicorp/consul"
    },
    ["..."]
  ],
  "homepage": "https://www.consul.io"
}
```

You can find the full example rule in action here: https://try.jsonata.org/idLYwVNdF

## Putting everything together 
To add the JSONata rule now to our custom datasource, we have escape our double quotes. 
This is at least the case if you are using a `renovate.json` file. 
In case you use `renovate.json5`
or defining it as self-hosted configuration in a `config.js` you can simply quote the template with single quotes, 
and you are done.

```json
{
  "regexManagers": [
    {
      "fileMatch": ["\\.ya?ml$"],
      "datasourceTemplate": "custom.hashicorp",
      "matchStrings": [
        "#\\s*renovate:\\s*(datasource=(?<datasource>.*?) )?depName=(?<depName>.*?)( versioning=(?<versioning>.*?))?\\s*\\w*:\\s*(?<currentValue>.*)\\s"
      ],
      "versioningTemplate": "{{#if versioning}}{{{versioning}}}{{else}}semver{{/if}}"
    }
  ],
  "customDatasources": {
    "hashicorp": {
      "defaultRegistryUrlTemplate": "https://api.releases.hashicorp.com/v1/releases/{{packageName}}",
      "transformTemplates": [
        "{ \"releases\": $[license_class=\"oss\"].{\"version\": version,\"releaseTimestamp\": timestamp_created,\"changelogUrl\": url_changelog,\"sourceUrl\": url_source_repository},\"homepage\": $[license_class=\"oss\"][0].url_project_website}"
      ]
    }
  }
}
```

## Conclusion
We have gone through all necessary steps to extract and update fully custom dependencies. 
From non-standard format in files to a non-standard registry.
This enables you to pretty much extract any dependency and update it. 

Maybe helpful to note here is that we have not looked at the full capabilties of either the `regex` manager nor the `custom` datasource.
Both have more helpful functionality like other [`matchStringStrategies`](https://docs.renovatebot.com/configuration-options/#matchstringsstrategy), 
[`hostRules`](https://docs.renovatebot.com/configuration-options/#hostrules) or API [`format`s](https://docs.renovatebot.com/modules/datasource/custom/#formats).
