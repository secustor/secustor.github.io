---
title: "Renovate: Automerge past CODEOWNERS"
date: 2026-11-10T00:05:24+02:00
draft: true
type: post
showToc: true
tags:
  - blog
  - renovate
  - RenovateBot
  - dependency-management
  - github
  - best-practices
---

A team enables "Require review from Code Owners" on their default branch, and a week later someone asks why Renovate stopped automerging.
Nothing changed in the `renovate.json`, and the PRs are green.
They are waiting for a review that no code owner is going to give to a patch bump of a linter.
In this blog I will go through why this happens and how to let Renovate automerge past CODEOWNERS without giving up the protection for everything else.

<!--more-->

## Why automerge stops

The Renovate docs warn about this in the [automerge](https://docs.renovatebot.com/key-concepts/automerge/) guide:
having a `CODEOWNERS` file could block automerging.
The reason is that every automerge type Renovate offers ends up at the same branch protection.

- `automergeType: "pr"` (the default) with [`platformAutomerge`](https://docs.renovatebot.com/configuration-options/#platformautomerge) enables GitHub's native auto-merge on the PR. GitHub then waits for all merge requirements, including the code owner review.
- With `platformAutomerge: false` Renovate tries to merge the PR itself, and GitHub rejects the merge for the same reason.
- `automergeType: "branch"` pushes the update directly to the base branch. Branch protection requires a pull request, so the push is rejected and Renovate falls back to creating a PR.

Renovate is doing what it should here.
It is the repository telling it that a human has to look at this.

## Why the approve bot does not help

If you only require an approving review, the Renovate docs point you to the approval helper apps.
These mark Renovate's automerging PRs as approved, and the required review count is satisfied.

Code owner reviews are a different requirement.
GitHub requires code owners to be users or teams with write permission on the repository.
The approval from the helper app counts as an approval, but not as one from a code owner of `package.json`.

## Option 1: Carve out files in CODEOWNERS

[CODEOWNERS](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners) allows a pattern without owners.
The last matching line wins, so you can remove the ownership for files which only Renovate touches.

```text title=".github/CODEOWNERS"
*                   @my-org/platform-team

# no owner, any user with write access can approve
/pnpm-lock.yaml
/.github/workflows/
```

This works for lock file maintenance and GitHub Actions pins.
It does not work for a `package.json` change, and you probably do not want it to.
The carve-out applies to humans as well, so anybody can now change your workflows with an approval from any colleague.

## Option 2: Let Renovate bypass the review

The cleaner approach is to keep CODEOWNERS as it is and give Renovate itself the right to skip the review.
[Repository rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets) support GitHub Apps as bypass actors.
This is the app Renovate runs as, `renovate[bot]` for the hosted Mend app or your own app if you self-host.
Both show up in the bypass list picker like any other installed app.

A bypass applies to every rule in a ruleset.
If you put the required status checks and the code owner review in the same ruleset, Renovate skips both.
So split them:

1. **Ruleset `ci`**: targets the default branch, requires your status checks, no bypass actors.
2. **Ruleset `review`**: targets the default branch, requires a pull request with "Require review from Code Owners", Renovate in the bypass list.

The bypass mode decides which automerge type you can use.

### Branch automerge

For direct pushes, the bypass mode has to be "Exempt".
"Always allow" is not enough here.
With "Exempt" the rules of the `review` ruleset are not evaluated for Renovate at all, and GitHub does not create a bypass entry in the audit log.
Combine this with [`automergeType: "branch"`](https://docs.renovatebot.com/configuration-options/#automergetype):

```json title="renovate.json"
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:best-practices"],
  "packageRules": [
    {
      "description": "Automerge non-major devDependencies without opening a PR",
      "matchDepTypes": ["devDependencies"],
      "matchUpdateTypes": ["minor", "patch"],
      "automerge": true,
      "automergeType": "branch"
    }
  ]
}
```

Renovate creates the `renovate/` branch, waits for the status checks on it, and pushes the commit to the base branch if they pass.
If they fail, or stay pending too long, you get a PR as usual, and that PR goes through code owner review like any other.
A nice side effect is that successful updates do not produce PR notifications at all.

### PR automerge

With bypass mode "For pull requests only", Renovate cannot push directly, but it can merge a PR without the code owner review.
GitHub's native auto-merge waits for all requirements, so let Renovate merge the PR itself:

```json title="renovate.json"
{
  "packageRules": [
    {
      "matchDepTypes": ["devDependencies"],
      "matchUpdateTypes": ["minor", "patch"],
      "automerge": true,
      "platformAutomerge": false
    }
  ]
}
```

Renovate checks that the status checks of the branch are green before it merges.
This also makes [`automergeSchedule`](https://docs.renovatebot.com/configuration-options/#automergeschedule) reliable, as native auto-merge is enabled at PR creation time and does not respect the schedule.

## The review moves into renovate.json

With the bypass in place, the code owners do not review the dependency updates any more.
They review the rules which decide what gets automerged.
Whoever can change the `packageRules` decides what skips CODEOWNERS.
So treat the config with the same care:

- **Own the config.** Add `renovate.json` and, if you use one, your shared preset repository to CODEOWNERS. A preset like `github>my-org/renovate-config` is outside the repository's protection, so protect it there.
- **Keep the automerge rules narrow.** `matchUpdateTypes` and `matchDepTypes` are the first filter. I avoid automerging majors and runtime dependencies without good test coverage. My [previous blog](../renovate_prevent_merging_bugs) covers the testing side.
- **Wait before merging.** [`minimumReleaseAge`](https://docs.renovatebot.com/configuration-options/#minimumreleaseage) gives the ecosystem time to find a compromised or broken release before it lands. `config:best-practices` sets 3 days for npm already.
- **Do not set `ignoreTests`.** It is `false` by default, and the status checks are the only gate left.
- **Mind the token when self-hosting.** The bypass belongs to the app, not to Renovate. Every workflow that can mint a token for that app can push to your default branch, and with "Exempt" those pushes do not show up as bypasses in the audit log. Use a dedicated app for Renovate and do not reuse its credentials for other automation.

Before merging a change to the automerge rules, check which updates it actually affects.
The [Renovate Config Debugger](https://renovate.secustor.dev/) answers "would this update automerge?" for a given dependency, so a reviewer does not have to work through the presets in their head.

## Conclusion

CODEOWNERS and automerge do not fight each other, they need to be told who is responsible for what.
Keep the code owner review for humans, let Renovate bypass it through a separate ruleset, and keep the status checks out of reach of any bypass.
The review does not disappear, it moves into `renovate.json`, where one approved rule covers hundreds of updates.

If you need support in implementing Renovate
or building your DEV platform, you can find my contacts on the [hire me](../hire) page.
