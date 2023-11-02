---
title: "OpenSSF: Our Journey to a 9 scoreboard score"
date: 2023-09-21T00:05:24+02:00
type: post
showToc: true
tags:
  - blog
  - renovate
  - RenovateBot
  - OpenSSF
  - best-practices
  - security
---

Notes:
- started with score ~5
- Vulnerabilities
  - count 116
  - All with one exception based on fixtures from package managers
  - Other would have been auto fixed after minimumAge would have been resolved
- SignedReleases 
- BinaryArtifacts
  - Gradle test fixtures included `graddle-wrapper.jar`
  - have been removed
- TokePermissions
  - Workflows with one Job had to be modified
  - 
