---
title: Renovating APM Packages
tags:
  - APM
  - Renovate
  - Release Please
  - Automation
  - Dependencies
  - GitHub Actions
---

[Last month]({% post_url 2026-12-07-packaging-agent-context-with-microsoft-apm %}) I packaged five sets of agent skills as APM packages, each with its own `apm.yml` and its own version. That solves distribution. It creates a second problem immediately: five packages release independently, and a consumer pinning one of them needs to hear about a bump without a human watching five repositories.

Two bots do that here. Release Please turns commits into per-package tags; Renovate reads those tags and raises the bump in every repository that depends on them. This is the wiring, and the one place it currently falls over.

## What Manual Tagging Costs

The obvious approach is a tag per repository. It doesn't work once packages diverge: `architecture-docs` at 0.0.8 and `devops` at 0.0.3 cannot both be expressed by one repository-level `v1.2.0`, and a tag that moves for any package tells a consumer nothing about which one changed.

The alternative is no tags at all, which is worse. An unpinned `apm install` resolves the default branch head and says so, so every consumer silently drifts — [I showed that warning last month]({% post_url 2026-12-07-packaging-agent-context-with-microsoft-apm %}#pinning-and-reproducibility). Pinned and automated beats pinned and forgotten.

## One Release Per Package

Release Please does the versioning, configured per package rather than per repository. If you have not set it up before, [my earlier post on it]({% post_url 2026-01-05-adding-release-please %}) covers the workflow; the part that matters here is the manifest:

```json
{
  "release-type": "simple",
  "include-component-in-tag": true,
  "include-v-in-tag": true,
  "tag-separator": "-",
  "separate-pull-requests": true,
  "packages": {
    "plugins/architecture-docs": {
      "component": "architecture-docs",
      "extra-files": [
        { "type": "yaml", "path": "apm.yml", "jsonpath": "$.version" }
      ]
    }
  }
}
```

`include-component-in-tag` with `tag-separator` produces `architecture-docs-v0.0.8` rather than a repository-wide tag. `extra-files` is the part that matters: it writes the released version back into that package's `apm.yml`, so the manifest and the tag are updated by the same commit and cannot disagree. Merging a feature under `plugins/architecture-docs` produces (excerpt):

```text
chore(main): release architecture-docs 0.0.8 (#40)

- version: 0.0.7
+ version: 0.0.8
```

and the tag `architecture-docs-v0.0.8`. With `apm pack --check-versions` gating pull requests, a bot that updated the tag but not the manifest would fail the build rather than publish a lie.

## How Renovate Reads Those Tags

Renovate's `apm` manager treats each `apm.yml` dependency as a `owner/repo[/subpath]#ref` git reference. It resolves the host to a datasource — `github-tags` on GitHub, `gitlab-tags` on GitLab, `git-tags` anywhere else — so `matchDatasources` in a rule filters, it does not choose. That distinction bites when you move a package off GitHub and wonder why a rule stopped applying.

The interesting part is scoping. Five packages share one repository, so every tag points at the same `owner/repo`; without a compatibility scope, Renovate would offer `devops-v0.0.3` to a repository depending on `architecture-docs`. The manager handles this itself: if the pin looks like a component tag, it derives `versionCompatibility` from it. The source is explicit about the forms it accepts:

```text
Match `<name>--v<version>`, `<name>-v<version>`, and `<name>_v<version>` tags.
```

The preset states that assumption explicitly rather than relying on the heuristic. A consuming repository opts in with one line in its `extends` array — `"github>milkyware/awesome-ai"` — and the rule applies to every `apm.yml` in that repository:

```json
{
  "matchManagers": ["apm"],
  "matchDatasources": ["github-tags"],
  "matchPackageNames": ["milkyware/awesome-ai"],
  "extractVersion": "^(?<version>.+)$",
  "versionCompatibility": "^(?<compatibility>.+)-v(?<version>\\d+\\.\\d+\\.\\d+(?:-[0-9A-Za-z.-]+)?(?:\\+[0-9A-Za-z.-]+)?)$",
  "versioning": "semver",
  "pinDigests": true
}
```

Trimmed: the file also sets a commit message topic, which is why the bot's commits name the package rather than only the version. Applied to the real tags, the named groups do the work:

```text
architecture-docs-v0.0.8  -> compatibility=architecture-docs  version=0.0.8
delivery-v0.0.7           -> compatibility=delivery           version=0.0.7
agent-workflow-v0.1.5     -> compatibility=agent-workflow     version=0.1.5
```

The compatibility group is the package name, and it is the pin's own value that is matched, not some repository-level identity. That is what keeps five streams apart while all five point at one repo.

## Digest Pins

`pinDigests: true` turns the tag pin into an immutable one, with the release preserved as a comment:

```text
-    - milkyware/awesome-ai/plugins/agent-workflow#agent-workflow-v0.1.4
+    - milkyware/awesome-ai/plugins/agent-workflow#6baa4d10fc00acc0e651417800543403b2adecac # agent-workflow-v0.1.5
```

A tag can be moved; a commit SHA cannot. The trailing comment is not decoration — it is where Renovate recovers the version for the *next* update. Pin to a bare SHA without it and the manager skips the entry as an unversioned reference, so the dependency stops updating silently. `apm.lock.yaml` records the same digest as `resolved_commit`, so a tampered tag cannot change what a build installs.

The preset then lets those commits land on their own. This is the second rule in the same file, with its labels:

```json
{
  "groupName": "Awesome AI Automerge",
  "matchManagers": ["apm"],
  "matchDatasources": ["github-tags"],
  "matchPackageNames": ["milkyware/awesome-ai"],
  "matchUpdateTypes": ["minor", "patch", "pin", "digest", "pinDigest"],
  "addLabels": ["awesome-ai"],
  "automerge": true,
  "minimumReleaseAge": "0 days"
}
```

Minor, patch and pin updates merge without review, and the zero-day release age deliberately overrides the fourteen days set at the top of that repository's config — a package you publish yourself does not need to cool off.

Two things to know before you switch that on. Renovate runs `apm install` as part of the update, so the pull request carries regenerated artefacts as well as the pin — the deployment the install re-derives appears in the same diff, not just the one changed line. Watch what a single install writes in a consuming repository before you let it merge unattended.

The other is `apm install --frozen` in the consumer's CI. It replays the digest in `apm.lock.yaml` and refuses when the manifest no longer matches, so a merged pin cannot pass review and then resolve to something else.

## Where It Breaks Down

Private repositories do not work yet. The `apm` manager shells out to `apm install`, and the token Renovate holds is not passed to that subprocess in the case I hit, so resolution fails against private sources. [`renovatebot/renovate#46876`](https://github.com/renovatebot/renovate/pull/46876) — *pass the github.com token to apm install* — addresses it and was still open at the time of writing.

The practical consequences: keep the packages public, or expect to bump pins by hand in the consuming repository until it lands. Everything above — the tag streams, the compatibility scope, the digest pins — works the same either way.

## Wrapping Up

The mechanism is worth copying even if you never run Renovate: a per-package tag that a bot writes from `extra-files`, and a version stream a dependency bot can parse. The cost is one preset and one regex.

The [sample repository](https://github.com/milkyware/awesome-ai) has the Release Please configuration and the `default.json` preset; the consumer side is any repository that extends it.
