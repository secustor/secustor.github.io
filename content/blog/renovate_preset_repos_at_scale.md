---
title: "Renovate: Managing preset repositories at scale"
date: 2026-11-10T00:05:24+02:00
draft: true
type: post
showToc: true
tags:
  - blog
  - renovate
  - RenovateBot
  - dependency-management
  - presets
  - best-practices
---

Once Renovate runs on more than a handful of repositories, copying `renovate.json` around stops working.
The usual answer is a shared preset repository, and that works well until the preset repository itself becomes large enough to need maintenance.
In this blog I want to share how I structure, version and roll out preset repositories,
and a change I made upstream in Renovate that removes the most annoying part of it: relative preset references.

<!--more-->

## Why a preset repository

Every repository with its own full Renovate config drifts.
One team adds a registry, another changes the schedule, a third copies an old config with deprecated options.
After a year you have dozens of slightly different configs, and changing anything organisation wide means opening dozens of PRs.

A [preset](https://docs.renovatebot.com/config-presets/) repository fixes that.
Each repository only extends the shared config and keeps its own overrides small:

```json title="renovate.json"
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>my-org/renovate-config"]
}
```

Without a file name, Renovate loads `default.json` from the root of `my-org/renovate-config`.
A change in that file applies to every repository with the next Renovate run.

That last sentence is both the benefit and the risk.

<!-- TODO(examples): a short real-world before/after, e.g. number of repos and how many configs diverged -->

## Split by concern

A single `default.json` grows fast.
Registries, grouping rules, automerge policies, schedules and security settings end up in one file of several hundred lines, and every review touches all of it.

I split the repository by concern instead and let `default.json` only compose the parts:

```text title="Preset repository layout"
default.json
system/registries.json
system/security.json
groups/aws.json
automerge/non-breaking.json
automerge/breaking.json
schedules/business-hours.json
schedules/quarterly.json
```

This has a few benefits:

- Reviews are scoped. A change to `groups/aws.json` does not touch the automerge policy.
- Consumers can pick parts. A repository which does not want automerge extends the parts it wants instead of `default.json`.
- Ownership can follow the files. The platform team owns `system/`, while application teams can contribute to `groups/`, enforced with a `CODEOWNERS` file.

This layout is taken from my demo repository [`secustor/relative-presets-demo`](https://github.com/secustor/relative-presets-demo), which we will use for the rest of this blog.

<!-- TODO(examples): show the content of one or two of the split files, e.g. system/registries.json and groups/aws.json -->

## Version your presets

If every repository extends the default branch, every merge in the preset repository is a release to the whole organisation at once.
A wrong `packageRule` there means a wave of wrong PRs in every repository, before anyone notices.

So I tag the preset repository and let consumers pin to a tag:

```json title="renovate.json"
{
  "extends": ["github>my-org/renovate-config#v1.0.0"]
}
```

The nice part is that you do not have to bump these tags by hand.
The [`renovate-config`](https://docs.renovatebot.com/modules/manager/renovate-config/) manager updates preset references which are already pinned to a version.
`github>my-org/renovate-config#v1.0.0` gets a PR to `#v1.1.0` once that tag exists, while a reference without a tag is left as it is.

This turns the rollout of a preset change into a normal dependency update.
Each repository gets a PR, its CI runs, and the rollout can be paused or reverted per repository.
You can even use the same tools as for any other dependency, like `minimumReleaseAge` or automerge, to control how fast new preset versions spread.

Be aware that the manager does not support `local>` presets, so this only works with the explicit platform prefixes like `github>` and `gitlab>`.

<!-- TODO(examples): packageRule for the renovate-config manager, e.g. automerge preset updates after a minimumReleaseAge, or a canary group of repositories -->

## The problem with nested presets

Here is where it used to get painful.
`default.json` has to reference the split files, and before Renovate 44.29.0 that meant writing the full address of each one:

```json title="default.json"
{
  "extends": [
    "github>my-org/renovate-config//system/registries",
    "github>my-org/renovate-config//groups/aws",
    "github>my-org/renovate-config//automerge/non-breaking"
  ]
}
```

These internal references carry no tag.
So a consumer pinned to `#v1.0.0` gets `default.json` from `v1.0.0`, and **every nested preset from the default branch**.
The pinning from the previous chapter silently only applied to the top level file.

To pin properly, you had to write `#v1.0.0` into every internal reference in every file, and rewrite all of them with each release.
I have seen release scripts doing exactly that with `sed`, and I have seen the bugs when one reference was missed.

The full address also hardcodes the owner and name of the repository.
Forking the preset repository, moving it to another organisation or testing a change from a branch all meant rewriting the references first.

This came up in the Renovate discussions more than once, for example in [#16983](https://github.com/renovatebot/renovate/discussions/16983) and [#24753](https://github.com/renovatebot/renovate/discussions/24753).

## Relative preset references

With [renovatebot/renovate#45211](https://github.com/renovatebot/renovate/pull/45211), released in [44.29.0](https://github.com/renovatebot/renovate/releases/tag/44.29.0), presets can reference other presets of the same repository with a relative path:

| Syntax | Resolves relative to                                       |
| ------ | ---------------------------------------------------------- |
| `./x`  | the directory of the preset file with the reference        |
| `../x` | the parent directory of the preset file with the reference |
| `/x`   | the root of the preset repository                          |

The `default.json` from above becomes:

```json title="default.json"
{
  "extends": ["./system/registries", "/groups/aws", "./automerge/non-breaking"]
}
```

Renovate resolves each relative reference to the source, repository and tag of the preset which contains it.
For a consumer extending `github>secustor/relative-presets-demo#v1.0.0`, the references above resolve to:

```text
github>secustor/relative-presets-demo//system/registries#v1.0.0
github>secustor/relative-presets-demo//groups/aws#v1.0.0
github>secustor/relative-presets-demo//automerge/non-breaking#v1.0.0
```

The tag is inherited, so every file is read from the same tag.
A release is now just a new Git tag, no rewriting needed.
And because neither the repository name nor the platform is part of the reference, a fork or a moved repository works without changes.

Relative references work for `github>`, `gitlab>`, `gitea>`, `forgejo>` and `local>` presets.

<!-- TODO(examples): a nested example using ../ from inside a subdirectory, e.g. automerge/breaking.json referencing ../schedules/quarterly -->

### Things to know

- Relative references only work inside presets. A repository's own `renovate.json` cannot use them, and `renovate-config-validator` does not catch that, so the error only shows up when Renovate runs.
- You cannot add a `#tag` to a relative reference. The tag always comes from the referencing preset.
- A relative reference points to a preset _file_. Sub-preset keys inside a file are not supported, the same limitation as for the `//path` syntax.
- Parameters work, e.g. `./group(eslint)`. Templates in the path, e.g. `./{{ env.TEAM }}/base`, are not resolved.
- A reference which escapes the repository root, like `../../oops`, fails in every repository which extends the preset.

### Ignoring a nested preset

[`ignorePresets`](https://docs.renovatebot.com/configuration-options/#ignorepresets) is matched against the resolved preset string, not the relative reference written in the preset.
So consumers have to use the absolute form, including the inherited tag:

```json title="renovate.json"
{
  "extends": ["github>my-org/renovate-config#v1.0.0"],
  "ignorePresets": [
    "github>my-org/renovate-config//automerge/non-breaking#v1.0.0"
  ]
}
```

If you are unsure about the exact string, paste the consumer config into the [Renovate Config Debugger](https://renovate.secustor.dev/).
Its preset tree lists every nested preset in the resolved form, including the inherited tag.
Without it, run Renovate with `LOG_LEVEL=debug` and look at `visitedPresets` in the `Resolved shallow config, without merging internal presets` message.

<!-- TODO(examples): note that this ignorePresets entry has to be bumped together with the tag; show how the renovate-config manager handles it, or recommend avoiding ignorePresets in favour of extending parts -->

## Validate the preset repository in CI

A broken preset breaks every repository which extends it, so the preset repository needs CI more than any other repository.
At the minimum, run the validator against every preset file:

```shell
npx --package renovate -- renovate-config-validator --strict default.json system/*.json groups/*.json
```

<!-- TODO(examples): GitHub Actions workflow running the validator on every preset file -->

The validator tells you whether a file is valid, not what it does once all presets are merged.
For that I use my [Renovate Config Debugger](https://renovate.secustor.dev/) ([introduction post](../renovate_config_debugger)), which shows the full preset tree and which preset set which value.
Paste a consumer config pinned to a branch or tag of your preset repository and check the result before you tag a release.

<!-- TODO(examples): screenshot of the preset tree of relative-presets-demo in the debugger -->

## Conclusion

To summarise my setup:

1. One preset repository, split by concern, with `default.json` composing the parts.
2. Relative references between the files, so a tag pins the whole tree.
3. Consumers pinned to tags, and Renovate rolling out new tags as normal PRs.
4. CI in the preset repository, because a mistake there is a mistake everywhere.

The demo repository is available at [`secustor/relative-presets-demo`](https://github.com/secustor/relative-presets-demo),
and the full documentation of relative references is in the [Renovate docs](https://docs.renovatebot.com/config-presets/#relative-preset-references).

If you need support in setting up Renovate for your organisation,
you can find my contacts on the [hire me](/hire/) page.
