---
title: "Renovate & Backstage: How to upgrade an Internal Developer Platform"
date: 2023-08-07T00:05:24+02:00
type: post
showToc: true
tags:
  - blog
  - renovate
  - RenovateBot
  - dependency-management
  - Backstage
---

- Why you should update dependencies
- usage `yarn backstage-cli versions:bump` vs Renovate package rules
- auto merging

## Backstages recommended method

```shell
yarn backstage-cli versions:bump --release <Backstage version>
``` 
This will update all your Backstage packages which are published by the Backstage project,
which are recognizable by the `@backstage` namespace of NPM packages.
An example of this is `@backstage/app-backend` or `@backstage/catalog`.

External plugins such as plugins from RoadieHQ can be added by the `pattern` flag like this:
```shell
yarn backstage-cli versions:bump --pattern '@{backstage,roadiehq}/*' --release <Backstage version>
```
The pattern matching used here is minimatch that can be tested with services like (TODO insert minimatch tester).

## Automate all dependencies
But what is about other dependencies like in `Dockerfile`s or other NPM packages?    
Here come dependency management tools like [RenovateBot](https://github.com/renovatebot/renovate) into the picture.

We will build now a complete configuration from the ground up to manage all dependencies using Renovate,
the usage of `backstage-cli versions:bump` is here not necessary anymore. 

Tough you may decide to manage the plugins' versions completely manually
or let Renovate simply run `versions:bump` for you.   
There are two tutorials that describe how to achieve this, both can be found in the [If you want to still use `versions:bump`](#if-you-want-to-still-use-versionsbump)

### Groundwork
Let's get started and begin with the basics. 

First, we add the Renovate JSON schema, so we get IntelliSense
(auto-completion) as well as validation in IDEs such as Jetbrains developers suite or VS Code.
This will improve your experience while writing up your config massively 
```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json"
}
```

Next, we will use one of the presets shipped by Renovate which come with a lot of helpful predefined configurations.
```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:best-practices"]
}
```
`config:best-practices` are the configurations which are considered best-practices by the Renovate Maintainers.
Some of the options this preset is configuring are:
- pinning of 
  - development dependencies 
  - GitHub Actions 
  - Dockerfile image references such as in `FROM` directives
- Add community-provided rules such as
  - Monorepo groupings (including the Backstage mono repo)
  - Replacements (rules to update dependency references in case of package movements)
  - Workarounds for common problems
- Enables the Dependency Dashboard as communication point with users
- 
- TODO add options

Now we have already got some useful PRs such as this grouped PR for all packages from the Backstage upstream repository.
TODO insert image of PR

Tough `backstage.json` isn't updated yet as this is a custom file specific to Backstage.
We configure Renovate to update this file too in the next section.

### Update `backstage.json`
Renovate comes with some powerful tools that allow you to update non-standard references too.
One of them are `customManagers`.
`customManager` give you a low-level interface
with which extractions and updates of generic version references in text file are possible. 

We now add such a `customManager` in its `regex` form
to extract the version field of `backstage.json` which looks like this: 
TODO check it really looks like this
```json
{
  "version": "1.22.0"
}
```

This configuration will look for any file named `backstage.json` in your repository,
extract the current value from the file
and then look for the published GitHub releases on the `backstage/backstage` repo.
The version of the releases will be compared
by using the `semver-coerced` versioning logic and if a newer version has been found the file will be finally updated.

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "customManagers": [
    {
      "customType": "regex",
      "fileMatch": "backstage\\.json$",
      "matchStrings": [
        "TODO"
      ],
      "depNameTemplate": "backstage/backstage",
      "datasourceTemplate": "github-release",
      "versioningTemplate": "semver-coerced"
    }
  ]
}
```
You can find a detailed explanation of this in another blog entry of mine (TODO insert reference to a custom datasource section)

### Dockerfile
#### Image references
Backstage uses its documentation as of writing this blog no sha pinning in their Dockerfile,
with that setup on each built the on any version of NodeJS tagged with `18-bookworm-slim` Docker can find.
This can be a local existing version, or if no local could be found the newest remote one.
Both is not ideal
as you can not know which version of the base image is running in production
and in case of a new release you are not rolling out a build based on the new base image. 

I see this most often as result of the maintenance overhead regarding managing sha pinning of Docker images. 
They are long, not human readable and change often.
Therefore, it makes sense to offload this to RenovateBot.

If you have set the `config:best-practices` preset
as described in [Groundwork](#groundwork) then Renovate will already pin your `FROM` references to it's SHA256 value
```dockerfile
# before
FROM node:18-bookworm-slim AS packages
# after Renovate pin
FROM node:18-bookworm-slim@sha256:aaaaaaaaaaaaaaaaaaa AS packages
```
If you want to prevent this specific behaviour you use this option: 
```json
{
  "ignorePresets": ["pinDockerfile"] TODO check if correct
}
```

#### Additional external tools 
There are generally three ways to inject external binaries in Docker images:
- copying binaries from another image 
- download of a binary
- package manager

##### Another image
Copying from another image is the easiest way and versions here are here natively supported by Renovate. 
Renovate will behave here the same as for `FROM` directives.
```dockerfile
COPY --from=myRegistry.com/anOrg/myImage:v1.0.0 /bin/myTool /bin/myTool
```

##### Direct download
If no image is avaiable there it is also possible to download the binary directly during the build process. 
For this the download url of the binary has to be identified
and all references of the version have to centralize in a single environment variable.
```dockerfile
# renovate depName=consul
ENV CONSUL_VERSION=1.15.0
RUN wget -qO- https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip | bsdtar -xvf- -O /usr/local/bin/
```

```json
{
  "customManagers": [
    {
      "customType": "regex",
      "fileMatch": ["Dockerfile$"],
      "datasourceTemplate": "custom.hashicorp",
      "matchStrings": [
        "#\\s*renovate:\\s*(datasource=(?<datasource>.*?) )?depName=(?<depName>.*?)( versioning=(?<versioning>.*?))?\\s*.*?_VERSION=(?<currentValue>.*)"
      ]
    }
  ]
}
```
With this setup in place we can create a `customManager` to extract the version and look up available versions online.
Usually Github releases or Git tags are used
tough it is also possible to use a generic API using `customDatasource`s.    

See ["Renovate: No Datasource? No problem!"](../renovate_custom_datasources/) for a comprehensive guide to setup the example above with a `customDatasource`.

#### Package Manager
Package manager are the trickiest for pinning
as they manage a lot of transient libraries which are not visible to the user.
This can lead easily to situation
in which package managers can not calculate a fitting version
as maybe one version of package A requires another version then package B.

My recommendation is to only pin packages on which the functionality of the ENTRYPOINT relies such as potential plugins.
```dockerfile
RUN apt install \
    # renovate datasource=repology depName=python
    python==3.10.1   TODO add example
```


## Thoughts regarding auto merging Backstage dependencies

## If you want to still use `versions:bump`...
### Completely manage Backstage and its plugins manually
TODO add section
### Let Renovate run `versions:bump`
TODO add section
## Conclusion
TODO, why I have chosen the one over the other solution
