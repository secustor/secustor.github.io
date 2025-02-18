---
title: "Backstage: How to set up Renovate"
date: 2025-02-19T00:05:24+02:00
type: post
showToc: true
tags:
  - blog
  - renovate
  - RenovateBot
  - dependency-management
  - Backstage
---

Ever struggled to set up Renovate with Backstage repositories?  

You are not alone! 🤗  

<!--more-->

I have created a set of Renovate presets over the last few months that can be used to configure Renovate for Backstage repositories, which I want to share with you today.

## Why

Renovate is a great tool to keep your dependencies up-to-date.
But it can be a bit tricky to set up Renovate as it comes with a lot of knobs and configurations.
This is especially true for Backstage repositories, as they have a specific structure and expect to have dependencies updated in a specific way.

## What does it do?

The provided presets are opinionated and are meant to be used for Backstage repositories.
They contain a set of rules that are meant to be used for most Backstage setups.

These features include:

- Renovate based upgrades to the latest Backstage release
- [Group Backstage updates together](https://github.com/secustor/backstage-renovate-config/blob/6df423e993a5f80b13266ba0d32f7ac65d5a1fa5/app.json5#L20-L24)
- [Prevent upgrades to frameworks that are not supported by Backstage](https://github.com/secustor/backstage-renovate-config/blob/main/presets/unsupported-framework-upgrades.json)
- [Group all PRs based on the plugin. Therefore, all updates of the `catalog` are grouped together including `catalog`, `catalog-backend` and so on](https://github.com/secustor/backstage-renovate-config/blob/main/presets/group-by-plugin.json)

## Usage

To use these presets, you need simply to add a new `extends` entry to your `renovate.json` file.
Here is an example of how to use the `default` preset which will work for any Renovate instance whether it is self-hosted or not:

```json
{
  "extends": [
    "github>secustor/backstage-renovate-config"
  ]
}
```

If you want to use specific features of the hosted Mend App or you are self-hosting Backstage then you can choose the specific preset like this:

```json
{
  "extends": [
    "github>secustor/backstage-renovate-config:self-hosted.json5"
  ]
}
```

A real life example of how to use this, can be found in my [Backstage plugins repo `secustor/backstage-plugins`](https://github.com/secustor/backstage-plugins/blob/main/renovate.json5)

For more information on how to configure Renovate presets, see the [Renovate documentation](https://docs.renovatebot.com/config-presets/)

And that's it! 🎉

If you have any questions or feedback, feel free to reach out to me via issues on the [Github repository `secustor/backstage-renovate-config`](https://github.com/secustor/backstage-renovate-config).
