---
title: "Renovate: Could you please bump that version?"
date: 2025-05-07T00:05:24+02:00
type: post
showToc: true
tags:
  - blog
  - renovate
  - RenovateBot
  - dependency-management
  - helm
---

Ever wished that [Renovate](https://github.com/renovatebot/renovate) increased that Chart version number in your Helm chart if the `appVersion` changes?
Or maybe you wanted to bump the version number even though a dependency changed, which is not a direct dependency?
Well, it can now!

<!--more-->

In this blog post, I will show you how to configure the newest addition to Renovate suite of features: **Generic Version Bump**.

## What is Generic Version Bump?

A generic version bump is in contrast to the existing [`bumpVersion`](https://docs.renovatebot.com/configuration-options/#bumpversion) feature, independent of the dependency manager.
It allows you to bump [semantic versions](https://semver.org/) in files based on a change in another file, even if they are not directly related.

The feature is triggered if any package file or lock file changes, so it is possible to trigger version bumps on lock file changes.

## How to use it?

The configuration is straightforward. You need to define a [`versionBumps`](https://docs.renovatebot.com/configuration-options/#bumpversions) array with the following properties:

- `filePatterns`: An array of [Renovate patterns](https://docs.renovatebot.com/string-pattern-matching/) which are matched against the relative path from the repo root. If any match, the `matchStrings` are applied.
- `matchStrings`: An array of regexes which are matched against the file content. Each regex has to contain a `version` named regex group. If any version is matched, then a bump is attempted.
- `bumpType`: The type of bump to perform. Can be `major`, `minor`, `patch` or `prerelease`.

These fields are templates and therefore support Renovates [templating syntax](https://docs.renovatebot.com/templates/).

## A basic bumpVersion example

In this example, we have a file `version.txt` which contains the version number.

```text title="version.txt"
1.0.0
```

and the following Renovate configuration:

```json title="A very simple bumpVersion example"
{
  "bumpVersions": [
    {
      "filePatterns": ["version.txt"],
      "matchStrings": ["^(?<version>.*)$"],
      "bumpType": "patch"
    }
  ]
}
```

This configuration will bump the version in `version.txt` to `1.0.1` on each upgrade.
Should multiple upgrades be grouped together in a single PR, the version will be bumped only once.

## An advanced (Helm) example

In this example, we have multiple Helm charts in our repository, and we want to bump the version number in `Chart.yaml` if the `appVersion` changes.

```yaml title="Chart.yaml"
apiVersion: v2
name: my-chart
version: 0.1.0
appVersion: 1.0.0
```

and the following Renovate configuration:

```json title="An advanced Helm example"
{
  "bumpVersions": [
    {
      "filePatterns": ["{{packageFileDir}}/Chart.{yaml,yml}"],
      "matchStrings": ["version:\\s(?<version>[^\\s]+)"],
      "bumpType": "{{#if isPatch}}patch{{else}}minor{{/if}}"
    }
  ]
}
```

This configuration will only consider `Chart.yaml` files in the same directory as the updated file.
The `version` in `Chart.yaml` is bumped to `0.2.0` if the patch level only of `appVersion` changes
( e.g. from `1.0.0` to `1.0.1`), otherwise, it will bump the minor level (e.g. from `1.0.0` to `1.1.0`).

The problem though with this configuration will only bump the version for dependencies withing the same `packageFileDir`.
This will happen if you group multiple upgrades together in a single PR, for example if you want to bump all chart at the same time.

Some background: Renovate will merge the template variables ( including `packageFileDir`) of all upgrades in the PR into a single context.
To solve this, we can use the `upgrades` context variable, which contains all upgrades in the PR.

With some templating magic, we can create a regex that matches all `Chart.yaml` files in the same directory as the updated files, while looking up the `packageFileDir` from the `upgrades` context.
Kudos to [KeepItSimpleStupid](https://github.com/KeepItSimpleStupid) which provided the regex magic in the [Feedback discussion](https://github.com/renovatebot/renovate/discussions/35770#discussioncomment-13210022).

```json title="An advanced Helm example with upgrades context"
{
  "bumpVersions": [
    {
      "filePatterns": [
        "/^({{#each (distinct (lookupArray upgrades \"packageFileDir\"))}}{{{.}}}{{#unless @last}}|{{/unless}}{{/each}})/Chart\\.(yaml|yml)$/"
      ],
      "matchStrings": ["version:\\s(?<version>[^\\s]+)"],
      "bumpType": "{{#if isPatch}}patch{{else}}minor{{/if}}"
    }
  ]
}
```

Let's break down the changes to the `filePatterns`:

```text
/^({{#each (distinct (lookupArray upgrades "packageFileDir"))}}{{{.}}}{{#unless @last}}|{{/unless}}{{/each}})/Chart\\.(yaml|yml)$/
```

This regex does the following:

- `/.../` Adding slashes to use regex matching
- `^` asserts the start of the string.
- `({{#each (distinct (lookupArray upgrades \"packageFileDir\"))}}{{{.}}}{{#unless @last}}|{{/unless}}{{/each}})` let's go through this as it is processed by Renovate:
  - `lookupArray upgrades \"packageFileDir\"` looks up the `packageFileDir` from the `upgrades` context, which contains all upgrades in the PR and returns an array of all `packageFileDir` values.
  - `distinct` removes duplicates from the array, so we only have unique directories.
  - `{{#each ...}}{{{ . }}}{{/each}}` iterates over the array and template each element.
  - `{{#unless @last}}|{{/unless}}` adds a pipe `|` between each element, except for the last one.
- `/Chart\\.(yaml|yml)$/` matches the `Chart.yaml` or `Chart.yml` file in the directory. Adding `$` asserts that we are not looking at a a subdirectory with the same name.

## Conclusion

The generic version bump feature is a powerful addition to Renovate, allowing you to bump versions based on file contents.
This feature can be used for any file format and not just for dependency management tools like npm, yarn, or pip.

I hope you like this newest addition to Renovate, and it will reduce the overhead while managing Helm Chart repos the same as it has done for me.

You can find this setup in this example repo: [secustor/renovate-bump-versions](https://github.com/secustor/renovate-bump-versions).
