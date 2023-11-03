---
title: "Renovate: Merge dependencies with confidence"
date: 2023-11-04T00:05:24+02:00
type: post
showToc: true
tags:
  - blog
  - renovate
  - RenovateBot
  - dependency-management
  - best-practices
---

This time I want to share my top strategies to prevent (as much as possible 😅) merging buggy dependencies
when using [Renovate](https://github.com/renovatebot/renovate/).
The tips can be used for manual merging or auto merging strategies if you already reached the needed maturity. 

<!--more-->

This blog is split in multiple parts. A general one with [General Recommendations](#general-recommendations) 
which apply to most projects and more [Renovate specific one](#what-does-renovate-bring-to-the-table). 

I recommend skimming at least both, but if you are not yet using Renovate or you are looking simply for some guidance, 
then each chapter can be read independently.

# General recommendations
Tough, this blog entry is mostly about ways to prevent merging buggy dependencies using [Renovate](https://github.com/renovatebot/renovate/).
I want to start with general good practices around managing and finding dependencies before they are merged.

## Run tests on each PR
This seems obvious at first glance, but it isn't...    
Sadly, having some of your own code is not enough. 
Based on the type of the dependency updated, different level of tests is needed. 

Unit tests are enough in case of software libraries,
tough the unit test have
to cover the used functionality of these libraries.
Mocking the libraries in this case is counterproductive
as we want to confirm that the libraries still return the results which are expected.

Functional tests are needed when talking about dependencies which are not directly part of the program.
An example for such dependencies is Docker images that are used as base images.

Unit tests will not cover all the problems which can appear.

## Install dependencies based on lock file
Most modern package managers come with lock file support such as NPM for Node.js (`package-lock.json`) and PDM
( `pdm.lock` ) this brings the benefit of reproducible builds and other benefits 
like checking hashes of your downloaded binary blobs against the expected ones.

Tough to make use of this improvement, you should not run generic installation commands,
as these are more frequent than not rewrite the lock files with new versions.
The basis here is the same as running it on your local machine.
Namely, the ranges defined in your package file. 
Which leads to potential bad code execution or ways of side channel attacks in your CI systems.

There are two common mechanisms to trigger a lock file-based installation of dependencies:
- a separate command e.g. ( `npm ci` )
- the CLI detects that it is inside a CI environment (e.g., PNPM)

In the first case, a manual intervention of the user in any case is needed. 
The user has to simply switch out the commands e.g. `npm install` --> `npm ci`.

The second one should be happening already implicitly. 
Most managers, which make use of this, try
to detect CI environments based on environment variables e.g. `CI` or vendor specific variables such as `CONTINUOUS_INTEGRATION`
for Travis CI.
If your manager makes use of this method,
you should confirm this by scanning your build logs
or comparing hash values of your build artifacts while triggering the CI specific build manually.

## Test integrations with libraries
For typesafe languages such as Java, C# or Go it most often enough to simply build your program, 
tough this is not the case for dynamically typed systems.
In other cases, like Python,
you have to test the API of external packages to get the same level of confidence for merges.

# What does Renovate bring to the table?
If you do not know what Renovate is, I recommend reading this blog first:
https://www.augmentedmind.de/2023/07/30/renovate-bot-introduction/

Renovate has some features which give you additional confidence to merge external chances.
Tough they cannot be a replacement for some fundamental testing as described above.

## Minimum release age
[`minimumReleaseAge`](https://docs.renovatebot.com/configuration-options/#minimumreleaseage) allows you to postpone updates a number of days.   

This allows you to opt out to be an early adopter and let other users try out changes before. 
Further, this gives the maintainers the change to fix bugs in their libraries. 

In the case of NPM, this feature also allows preventing using of "unpublished" releases. 
For context, NPM releases can be unlisted if they are not older than 3 days
```json
{
  "packageRules": [
    {
      "matchDatasources": ["npm"],
      "minimumReleaseAge": "4 days"
    }
  ]
}
```

## Merge confidence
`mergeConfidence` is a by Renovate calculated value which describes how confident you can be to merge this dependency upgrade.
This value is calculated based on different factors which are captured by the hosted Renovate App:
- the age of the release
- adoption (how many by Renovate opened PRs have been merged and not rolled back)
- CI status (are the CI pipelines of RenovateApp users pass for this dependency update?)

Available values are:
- `low`
- `neutral`
- `high`
- `very high`

**! This feature is only available for the hosted RenovateApp on GitHub, or if you self-host a Mend.io API key. !**
```json
{
  "packageRules": [
    {
      "matchConfidence": "very high",
      "automerge": true
    }
  ]
}
```

# Summary
I hope this helped you on your way to more reliable dependency updates. 

If you need support in implementing Renovate
or building your DEV platform, you can find my contacts on the [hire me](../hire) page.
