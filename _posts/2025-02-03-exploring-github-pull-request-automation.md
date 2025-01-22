---
title: Exploring GitHub Pull Requests Automation
category: Automation
tags:
  - GitHub
  - GitHub Workflows
  - Pull Requests
  - PRs
  - Automation
  - Productivity
---

As development teams grow and projects become more complex, automating processes becomes critical to maintaining productivity and code quality. I'm a big fan of using Azure Pipelines to automate builds, testing, and general code quality. However, recently, I've started exploring GitHub Workflows to automate managing pull requests (PR) to make it easier to identify what they relate to.

In this post, I want to share my experience setting up some initial workflows to handle tagging PRs. Whether you're new to GitHub Actions or looking for ideas to enhance your current CI/CD pipeline, this guide offers practical insights and tips to help you get started.

## Automating GitHub

The majority of my CI/CD pipeline experience has centred around **Azure DevOps and Azure Pipeline** which I've used extensively for CI/CD pipelines in many projects. As I've started to use GitHub more, I've wanted to experiment with the **[GitHub CLI](https://cli.github.com/)** to easily integrate with the GitHub API to automate processes.

``` bash
gh pr view 1 --repo owner/scratchpad
```

As the example the above command will retrieve and display details about **PR #1 in the specified repo**.

``` bash
gh pr view 1 --repo owner/scratchpad --json id,title,body
```

In addition, the `--json` argument can be added to many commands to return a JSON object, allowing programmatic handling of the responses, such as using `ConvertFrom-Json` **in PowerShell**.

### Assigning Reviewers

The first workflow I wanted to create was to automate assigning a configurable list of reviewers to PRs.

``` powershell
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$PRNumber,
    [Parameter(Mandatory = $true)]
    [string[]]$Reviewers
)
begin
{
    $InformationPreference = 'Continue'
    if ($env:RUNNER_DEBUG)
    {
        $DebugPreference = 'Continue'
        $VerbosePreference = 'Continue'
    }
}
process
{
    Write-Debug "prNumber=$PRNumber"
    Write-Debug "reviewers=$($reviewers | ConvertTo-Json -Compress)"

    Write-Debug "Getting PR"
    $pr = gh pr view $prNumber --json author | ConvertFrom-Json
    $author = $pr.author.login
    Write-Verbose "author=$author"

    Write-Debug "Filtering out author"
    $reviewers = $reviewers | Where-Object { $_ -ine $author }

    $reviewersStr = $reviewers | ConvertTo-Json -Compress
    Write-Verbose "reviewersStr=$reviewersStr"

    Write-Debug "Getting current repo"
    $repo = gh repo view --json name,owner | ConvertFrom-Json

    foreach ($r in $reviewers)
    {
        Write-Debug "Assigning reviewer $r"
        gh api --method POST `
            -H "Accept: application/vnd.github+json" `
            -H "X-GitHub-Api-Version: 2022-11-28" `
            /repos/$($repo.owner.login)/$($repo.name)/pulls/$prNumber/requested_reviewers `
            -f "reviewers[]=$r" `
            --silent
    }

    Write-Information "Assigned reviewers"
}
```

The scripts takes parameters for a **PR number and GitHub usernames to be assigned as reviewers**. Using the GitHub CLI, the author of the repo is evaluated and removed from the list of reviewers with the remaining reviewers added using the `gh api` command.

**N.B.** The `gh api` command is currently used to add the reviewers due to a **[bug in the handling of workflow permissions](https://github.com/cli/cli/issues/4844)**.

<!-- {% raw %} -->
``` yaml
name: Assign Reviewers

on:
  pull_request:
    types:
      - opened
      - ready_for_review
      - reopened

jobs:
  assign-reviewers:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Print Environment Variables
        shell: pwsh
        run: |
          Get-ChildItem Env: | ForEach-Object {Write-Host "$($_.Name)=$($_.Value)"}

      - name: Assign Reviewers
        shell: pwsh
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          ./scripts/AssignReviewers.ps1 `
            -PRNumber "${{ github.event.number }}" `
            -Reviewers "github-user1", "github-user2"
```
<!-- {% endraw %} -->

The above workflow is triggered when a pull request is opened (including re-opened and published after drafting) and executes the script passing in values for **PRNumber and Reviewers**. To authenticate the CLI used in the script, the `GH_TOKEN` environment variable is set using the `${{ github.token }}` workflow variable.

Adding the reviewers automatically results in greater awareness by triggering notifications and greater ownership of code reviews.

### Tagging

When dealing with a large number of PRs, it's important to be able to quickly and easily identify what it relates to. To help with this I developed a workflow to start tagging PRs to categorise them.

``` markdown
<!-- Provide the release in the format vx.x.x.x -->
**Release:**

<!-- Other PR template details ...-->
```

Firstly I created a **[pull request template](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/creating-a-pull-request-template-for-your-repository)** like above to capture certain details when the pull request is raised. This template is then placed at **.github\pull_request_template.md**.

``` powershell
[CmdletBinding()]
param (
  [Parameter(Mandatory=$true)]
  [string]$PRNumber,
  [Parameter()]
  [string[]]$SupportedBranchTypes = @("feature","hotfix","release")
)
begin {
  $InformationPreference = 'Continue'
  if ($env:RUNNER_DEBUG)
  {
    $DebugPreference = 'Continue'
    $VerbosePreference = 'Continue'
  }
}
process {
  function LabelPR {
    param (
      [Parameter(Mandatory=$true)]
      [string]$PRNumber,
      [Parameter(Mandatory=$true)]
      [string]$Label
    )
    process {
      Write-Verbose "label=$Label"

      Write-Debug "Getting labels"
      $labels = gh label list --json name | ConvertFrom-Json | Select-Object -ExpandProperty name

      Write-Debug "Check label exists"
      $exists = $labels -contains $Label
      if (-not $exists)
      {
        Write-Debug "Creating label"
        gh label create $Label
      }

      Write-Information "Labelling PR with `"$Label`""
      gh pr edit $PRNumber --add-label $Label | Out-Null
    }
  }

  Write-Verbose "prNumber=$prNumber"

  Write-Debug "Getting PR content"
  $pr = gh pr view $prNumber --json id,body,state,baseRefName,headRefName,createdAt | ConvertFrom-Json

  $regex = "(?<!<!--.*)(?<=\*{2}[Rr]elease:?\*{2}\s?)(v\d(\.\d){2,3})"
  Write-Verbose "regex=$regex"

  Write-Debug "Matching release number"
  $match = $pr.body -match $regex

  if ($match)
  {
    $releaseNumber = $Matches[0]
    LabelPR -PRNumber $PRNumber -Label $releaseNumber
  }

  if ($SupportedBranchTypes)
  {
    Write-Debug "Splitting branch name"
    $branchSplit = $pr.headRefName -split "/"
    $branchType = $branchSplit[0].ToLower()
    Write-Verbose "branchType=$branchType"

    if ($branchType -in $SupportedBranchTypes)
    {
      LabelPR -PRNumber $PRNumber -Label $branchType
    }
    else 
    {
      Write-Warning "Invalid branch type $branchType"
    }
  }
}
```

I've created a PowerShell script to process the pull request. There are a few key aspects to note:

- A private helper function `LabelPR` has been added to **upsert labels**
- Regex is used to extract the value provided for the **release** in the pull request body and added as a label
- Branches conforming to the ***branchType*/name** format have the prefix extracted and added as a tag

<!-- {% raw %} -->
``` yaml
name: Label PR

on: 
  pull_request: 
    types:
      - opened
      - edited
      - ready_for_review
      - reopened

jobs:
  job:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      
      - name: Print Environment Variables
        shell: pwsh
        run: |
          Get-ChildItem Env: | ForEach-Object {Write-Host "$($_.Name)=$($_.Value)"}

      - name: Label PR
        shell: pwsh
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          ./scripts/LabelPR.ps1 `
            -PRNumber "${{ github.event.number }}"
```
<!-- {% endraw %} -->

Like the **[previous automation](#assigning-reviewers)**, the PowerShell script is attached to a workflow with **pull request triggers**.

![image1](/images/exploring-github-pull-request-automation/image1.png)

The resulting tags can then be used to distinguish **features from hotfixes** and which requests belong to **version X or version Y** allowing easier prioritisation of PRs so that more urgent requests are reviewed first. This automation could be expanded further by adding more details to the pull request template and then extracting these as tags.

## Wrapping Up  

Automation is a powerful tool for reducing repetitive tasks and improving workflow efficiency, and GitHub Workflows has proven to be a versatile platform for managing pull requests. By automating processes like assigning reviewers and tagging PRs, you can streamline collaboration, enhance visibility, and prioritise tasks more effectively.

The workflows in this post are just the beginning. GitHub Actions and the GitHub CLI offers a wealth of possibilities to extend automation even further and building custom scripts tailored to your team's needs and processes. Whether you're new to GitHub automation or already familiar with it, experimenting with workflows like these can open up new opportunities to enhance your development process.

I've thoroughly enjoyed exploring GitHub Workflows and the CLI and plan to continue experimenting. I hope you've enjoyed this post and if you've tried something similar or have comments, please feel free to share below.
