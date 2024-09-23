---
title: Automating Scanning For Secrets
category: DevOps
tags:
 - Azure Pipeline
 - Pipeline
 - GitLeaks
 - DevOps
 - Automation
---

Source control is the foundation of software development for many reasons including tracking changes, collaboration, and backup/recovery. One of the most popular source control tools is **Git**. However, due to the often rapid nature of development, sometimes sensitive information, such as API keys, credentials, tokens, and other secrets, may unintentionally get committed to the repository.

Keeping secrets out of source code is important for several key reasons:

1. **Prevent Unauthorized Access:**
   Exposing credentials in a repository gives attackers an easy path to access private infrastructure, databases, cloud services, or APIs. Once access is gained, they can steal, modify, or even delete valuable data.

2. **Comply with Security Regulations:**
   Many organizations are bound by stringent regulations, like GDPR, PCI DSS, or HIPAA, that require strict data handling and security measures. Exposing secrets can lead to non-compliance and hefty fines.

3. **Avoid Long-Term Impact:**
   Even after a secret is removed from a repository, Git's version history retains every commit unless it's purged. This means that secrets can still be retrieved if not properly cleaned up, prolonging the exposure risk.

4. **Scale and Automate Security Practices:**
   Regular, manual checks for secrets are tedious and error-prone. Automating this process ensures that every commit and pull request is scanned for potential vulnerabilities, reducing human oversight and improving overall security hygiene.

As mentioned, there is limits to scanning source code and history manually to ensure it remains secret free. Therefore, automating this process is crucial in allowing Git repos to scale and identifying leaks quicker.

## Automating Scanning with GitLeaks in an Azure Pipeline

There are a number of tools available to automate this process from open-source such as **[GitLeaks](https://github.com/gitleaks/gitleaks)**, to paid such as **[SpectralOps](https://spectralops.io/features/)** and even built-in to some developer platforms such as **[Azure DevOps](https://learn.microsoft.com/en-us/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops&tabs=yaml)**.

For this post, I'm going to demonstrate integrating **GitLeaks with Azure Pipelines** to automate scanning for secrets. GitLeaks is a fantastic open-source tool, actively maintained by many contributors, which is designed to detect hardcoded secrets like API keys and credentials in your Git repositories.

``` yml
jobs:
  - job: GitLeaksScan
    displayName: GitLeaks Scan
    variables:
      image: 'zricethezav/gitleaks:latest'
      image_cache_path: $(Agent.TempDirectory)/.cache/docker
      image_cache_tar: ${{variables.image_cache_path}}/gitleaks.tar
    steps:
    - template: PrintEnvironmentVariables.azure-pipelines.yml

    - template: PrintTree.azure-pipelines.yml

    - task: PowerShell@2
      displayName: Build Cache Key
      inputs:
        pwsh: true
        targetType: inline
        script: |
          if ($env:SYSTEM_DEBUG)
          {
              $DebugPreference = 'Continue'
              $VerbosePreference = 'Continue'
          }

          $timestamp = [datetime]::UtcNow.ToString("yyyy-MM-dd")
          $cacheKey = "docker | $(Agent.OS) | $timestamp"
          Write-Verbose "cacheKey=$cacheKey"

          Write-Host "##vso[task.setvariable variable=CacheKey;]$cacheKey"

    - task: Cache@2
      displayName: Setup Docker Image Cache
      inputs:
        key: $(CacheKey)
        path: ${{variables.image_cache_path}}

    - task: PowerShell@2
      displayName: Load GitLeaks Image
      inputs:
        pwsh: true
        targetType: inline
        script: |
          if ($env:SYSTEM_DEBUG)
          {
              $DebugPreference = 'Continue'
              $VerbosePreference = 'Continue'
          }

          $tarPath = "${{variables.image_cache_tar}}"
          Write-Verbose "tarPath=$tarPath"

          if (Test-Path $tarPath) 
          {
            Write-Debug "Loading cached gitleaks image"
            docker load -i $tarPath
            Write-Information "Loaded cached gitleaks image"
            return
          }
          Write-Debug "Pulling gitleaks docker image"
          docker pull ${{variables.image}}
          Write-Information "Pulled gitleaks docker image"

          $cachePath = "${{variables.image_cache_path}}"
          Write-Verbose "cachePath=$cachePath"

          New-Item -Path $cachePath -ItemType Directory -Force | Out-Null
          
          Write-Debug "Saving gitleaks image to cache"
          docker save ${{variables.image}} -o $tarPath
          Write-Information "Saved gitleaks image to cache"
        informationPreference: continue

    - task: PowerShell@2
      displayName: GitLeaks Scan
      inputs:
        pwsh: true
        targetType: inline
        script: |
          if ($env:SYSTEM_DEBUG)
          {
              $DebugPreference = 'Continue'
              $VerbosePreference = 'Continue'
          }

          docker run --rm `
            -v .:/mnt `
            ${{variables.image}} git /mnt --exit-code 1
        informationPreference: continue

```