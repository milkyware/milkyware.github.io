---
title: Packaging Agent Context with Microsoft APM
tags:
  - APM
  - Microsoft
  - AI
  - Agents
  - Copilot
  - Claude
  - OpenCode
  - Packaging
  - Dependencies
---

Earlier this year I packaged my architecture prompts as a GitHub Copilot CLI plugin, and [that post]({% post_url 2026-06-01-creating-a-github-copilot-cli-plugin %}) covered the build: `plugin.json`, a marketplace manifest, and a release pipeline that bumped versions on every merge. It replaced sharing prompts by copy-paste with installable, versioned skills.

It also only worked in the Copilot CLI. **Microsoft Agent Package Manager** ([APM](https://microsoft.github.io/apm/)) rebuilds the same repository so that one package installs into Copilot, Claude Code and OpenCode — or anything else on [its targets list](https://microsoft.github.io/apm/reference/targets-matrix/) — from a single manifest.

## Why Agent Context Needs a Package Manager

Prompt collections rot in three specific ways. Nothing carries a version, so two people with the same folder are running different text. Nothing pins, so an upstream edit arrives whenever you next sync. And there is no portable layout, so supporting a second harness means maintaining a second copy.

The plugin format fixed two of the three. `plugin.json` carried a version and a marketplace manifest carried the catalogue, but both were Copilot-shaped: fine at the time, a dead end the moment I wanted the same skills in Claude Code.

APM splits authoring from delivery. The package body is plain skills, prompts and agents; the manifest declares which harnesses should receive them; `apm install` writes each primitive to the directory that harness actually reads.

## Before You Start

You need git and the APM CLI. Everything below is reproduced against 0.35.1, released 11 November 2026; Homebrew, Scoop, pip and the Unix installer are all covered in the [installation docs](https://microsoft.github.io/apm/getting-started/installation/).

```powershell
winget install --id Microsoft.APM --exact --source winget
apm --version
```

Update it with `winget upgrade`, not `apm self-update` — the package manager owns the binary once you install it that way.

## What APM Defines

A distributable package is a directory with an `apm.yml`. For `architecture-docs`, trimmed to the fields that matter here:

```yaml
name: architecture-docs
version: 0.0.8
description: >-
  Generate Architecture Decision Records (ADRs) and High-Level Design (HLD)
  documents with structured, gated workflows.
author: MilkyWare
license: MIT
targets:
  - copilot
  - claude
  - opencode
includes: auto
```

`targets` is the field that replaces the per-harness copy. The package declares who should receive it; `apm install` works out where each primitive goes. `includes: auto` takes everything supported from the conventional `.apm/` directory, rather than enumerating each skill path the way `plugin.json` had to.

The repository root has a second `apm.yml` acting as the catalogue. `apm pack` compiles its `marketplace:` block into `.claude-plugin/marketplace.json`:

```yaml
marketplace:
  owner:
    name: MilkyWare
  versioning:
    strategy: tag_pattern
  build:
    tagPattern: "{name}-v{version}"
  packages:
    - name: architecture-docs
      source: ./plugins/architecture-docs
```

Local packages deliberately omit `version`, so each package's own `apm.yml` stays the single source of truth. `versioning.strategy: tag_pattern` is what makes a version bump mean one package rather than all five; `build.tagPattern` only formats the tag string.

## Converting the Plugin Repository

The move was mostly deleting. `plugin.json` and the hand-written marketplace file went; skills moved from `skills/<name>/SKILL.md` to `.apm/skills/<name>/SKILL.md`; every package gained an `apm.yml`.

`apm pack` now derives everything flat. The only generated file that gets committed is the root catalogue, because `apm marketplace add` reads it at a fixed path and a consumer shouldn't need a build step to subscribe. The per-package `.claude-plugin/` and `.github/` manifests are build output and are gitignored.

Two checks validate the generated state without writing anything, and both run on every pull request:

```bash
apm pack --check-versions --check-clean --dry-run
```

```text
[*] Version alignment OK [strategy=tag_pattern]
[i]     plugins/agent-workflow  0.1.5  -> tag agent-workflow-v0.1.5  [matches]
[i]     plugins/architecture-docs  0.0.8  -> tag architecture-docs-v0.0.8  [matches]
[i]     plugins/code-quality  0.0.2  -> tag code-quality-v0.0.2  [matches]
[i]     plugins/delivery  0.0.7  -> tag delivery-v0.0.7  [matches]
[i]     plugins/devops  0.0.3  -> tag devops-v0.0.3  [matches]
[*] Marketplace working tree clean [outputs=claude]
[i]     .claude-plugin/marketplace.json  [unchanged]
```

`--check-versions` exits 3 when a package version disagrees with its expected tag. `--check-clean` exits 4 when the committed catalogue has drifted from what `apm pack` would write. Those two exit codes are the entire release gate.

One consequence if you followed [the plugin post]({% post_url 2026-06-01-creating-a-github-copilot-cli-plugin %}): in this repository the `.github/plugin/` marketplace is no longer published, and consumers resolve the package through APM instead, with `targets:` deciding which harnesses receive it. `apm pack` can still emit a plugin-format marketplace (`--format plugin`); I simply stopped publishing one.

## Installing Into a Harness

Register the catalogue once, then let `apm.yml` say which harnesses you use:

```bash
apm marketplace add milkyware/awesome-ai
```

```yaml
name: demo
version: 1.0.0
targets:
  - copilot
  - claude
  - opencode
dependencies:
  apm:
    - milkyware/awesome-ai/plugins/architecture-docs#architecture-docs-v0.0.8
```

The dependency form matters. `owner/repo/path#tag` is manifest syntax. The `name@marketplace#tag` shorthand you may have seen is an `apm install` argument only — put it in `apm.yml` and parsing fails with "Shorthand '@alias' is not supported".

```text
[>] Installing dependencies from apm.yml...
[i] Targets: claude, copilot, opencode  (source: apm.yml)
  [+] github.com/milkyware/awesome-ai/plugins/architecture-docs#architecture-docs-v0.0.8
  |-- 3 skill(s) integrated -> .agents/skills/, .claude/skills/
[*] Installed 1 APM dependency in 5.3s.
```

Three skills, two directories. Copilot and OpenCode both read the shared `.agents/skills/`; Claude Code reads `.claude/skills/`. That convergence — the `SKILL.md` format is now common across most harnesses — is why one deployed copy serves several tools, while agents and instructions, which have not converged, still deploy per harness.

The lockfile is more than a dependency lock. It records the resolved commit, the files deployed into the project, and a SHA-256 per deployed file — enough to reproduce the install, track what was written where, and notice when a file changes underneath you:

```yaml
- repo_url: milkyware/awesome-ai
  name: architecture-docs
  resolved_commit: c2ee559479d3045b53da3b67ab9b8400cd19fef2
  resolved_ref: architecture-docs-v0.0.8
  virtual_path: plugins/architecture-docs
  deployed_files:
  - .agents/skills/generate-adr/SKILL.md
  - .claude/skills/generate-adr/SKILL.md
  deployed_file_hashes:
    .agents/skills/generate-adr/SKILL.md: sha256:6852d2804356ec2e58c250b801294f0ea51aa2f32da7ce48dd8d5bea58b5dc20
    .claude/skills/generate-adr/SKILL.md: sha256:6852d2804356ec2e58c250b801294f0ea51aa2f32da7ce48dd8d5bea58b5dc20
```

The same hash in both locations is the convergence claim made concrete: one file's content, two harnesses. A `content_hash` over the package as a whole sits alongside it.

## More Harnesses, Same Manifest

The [targets matrix](https://microsoft.github.io/apm/reference/targets-matrix/) lists every harness APM deploys to, with the directory and supported primitives for each. Your manifest names as many as you need; the packages you depend on decide what they can supply. A package that can't serve the target fails closed rather than deploying nothing quietly:

```text
[x] Failed to install APM dependencies:
milkyware/awesome-ai/plugins/agent-workflow declares targets [copilot,
opencode] but you requested [claude]; nothing was deployed
Install with --target copilot, or ask the package author to add claude to its
targets (declared: copilot, opencode).
```

`--target` on the command line is an override, not a configuration. On a first install with no manifest it persists the choice to the new `apm.yml`, but after that it changes one run only. To actually move a project between harnesses, edit `targets:` and run a plain `apm install`; APM then reconciles its managed deployment, removing the files it placed for the dropped target and leaving anything else in those directories alone.

## Pinning and Reproducibility

An install without a ref resolves the default branch head and says so:

```text
[!] 1 dependency unpinned: milkyware/awesome-ai -- add #tag or #sha to prevent drift
```

That is exactly the drift a lockfile exists to prevent, so pin each package to its own release tag:

```bash
apm install 'architecture-docs@awesome-ai#architecture-docs-v0.0.8'
```

A ref on `apm marketplace add` is not a substitute. I registered the catalogue at a commit from the 0.0.7 release and then installed unpinned; the package still resolved to the current head, because the ref freezes the catalogue file, not the package sources.

With both `apm.yml` and `apm.lock.yaml` committed, CI runs `--frozen`, which refuses when the declaration has moved:

```text
[x] --frozen: apm.lock.yaml is out of sync with apm.yml.
  - milkyware/awesome-ai/plugins/architecture-docs: declared source, ref, host
 provider, or transport differs from apm.lock.yaml
```

## Keeping Versions in Step

In my repository, Release Please bumps each package's `apm.yml` version independently, and Renovate proposes the matching tag bump in consuming repositories. That configuration, and the one case it currently handles badly, is next month's post.

## Wrapping Up

APM treats delivering agent context as a packaging problem rather than a documentation problem: a small manifest, a lockfile, and a deploy step that knows each harness's layout. Adding a harness stopped meaning adding a copy.

The [sample repository](https://github.com/milkyware/awesome-ai) has all five packages, the release workflows and the CI checks described here.
