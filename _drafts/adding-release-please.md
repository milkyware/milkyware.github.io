---
title: Adding Release Please
tags:
  - Release Please
  - GitHub Actions
  - DevOps
  - Release
---

I've been using the **[Microsoft Graph SDK](https://github.com/microsoftgraph/msgraph-sdk-dotnet)** in various projects for a while now and stumbled across **[Release Please](https://github.com/googleapis/release-please)** being used to release the library. Preparing releases and ensuring they're accurate for what is included takes time and is often made difficult due to different styles of commit messages, so automating my release process and ensuring consistency is something I've wanted to look into for a while.

For this post, I'll introduce Release Please and how i've implemented it in my projects as well as how I've added validation to ensure pull request commits remain consistent and conform to Release Please conventions.

## Introducing Release Please

Release Please is a Google project which monitors the commits of a GitHub repo and automates:

- CHANGELOG generation
- Creation of GitHub releases
- Calculation of version numbers

To do this, Release Please looks for commit messages conforming to the **[Conventional Commits spec](https://www.conventionalcommits.org/)**. This is a set of rules on how to structure messages to create an explicit git history and indicate the type of change on the project. The general structure of Conventional Commits is:

```txt
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Often, just the top part of the message is needed and generally the most common *types* will be `fix:` and `feat:` corresponding to **patch** and **minor** version changes respectively. In addition, suffixing a *type* with `!` (e.g. `feat!:`) indicates a breaking change which corresponds to a **major** version change.

![image1](/images/adding-release-please/image1.png)

Conventional Commits will then trigger Release Please to create a ***release Pull Request*** containing a summary of the changes made since the last release along with calculating the next version number based on the types of changes made. As part of the release PR, a `CHANGELOG.md` will be created/updated containing the same details as PR description to create a single history of the changes.

![image2](/images/adding-release-please/image2.png)

Merging this PR then triggers a GitHub release to be created along with the associated Git tag. So let's have a look at how how to set it up.

### Setting Up Release Please

## Validating PR Titles

```bash
npm i release-please -g
```

[![milkyware/blog-release-please - GitHub](https://gh-card.dev/repos/milkyware/blog-release-please.svg)](https://github.com/milkyware/blog-release-please)

 My preferred release strategy has long been using Git tagging (particularly GitHub releases), however, preparing releases and ensuring they're accurate for what is included takes time and is often made difficult due to different styles of commit titles.
