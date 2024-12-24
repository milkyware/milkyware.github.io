---
title: Scaling CI Testing with an Azure Pipeline for Monorepos
category: DevOps
tags:
  - Dotnet
  - .NET
  - Azure DevOps
  - Azure Pipelines
  - Tests
  - Testing
  - CI
  - Monorepos
---

Continuous Integration (CI) in monorepos often presents challenges as the codebase scales. Running all tests on every commit is inefficient, particularly for large repositories with multiple solutions and test projects, whereas defining a CI pipeline per solution is repetitive and doesn't scale easily. To address this, I've implemented an Azure Pipeline that dynamically identifies and runs only the test projects affected by code changes. This pipeline simplifies CI operations and scales efficiently as more test projects are added.

## Key Features of the Pipeline

### 1. Dynamic Test Discovery

The pipeline identifies changes in a branch compared to a base branch (e.g., `main`) using the `git diff` command. It uses a configurable depth parameter to map changes to specific directories and locate affected test projects. This approach ensures that only impacted tests are executed, saving time and resources.

### 2. Modular Configuration

The pipeline offers several parameters for customization:

- **comparisonBranch:** The base branch for evaluating changes.
- **comparisonDepth:** Determines how deeply the directory structure is analyzed for changes.
- **buildConfiguration:** Specifies the build configuration (e.g., Debug or Release).
- **dotnetVersions:** Lists .NET versions required to run the tests.
- **excludedTestProjects:** Allows exclusion of specific test projects.

These parameters provide flexibility to adapt the pipeline to different project structures and team requirements.

### 3. Intelligent Test Identification

The pipeline uses the following heuristics to identify test projects:

- Checks if the `IsTestProject` property is defined in the `.csproj` file.
- Verifies if testing frameworks like MSTest, NUnit, or xUnit are referenced in the project file.

This logic ensures that only genuine test projects are included in the test run.

### 4. Exclusion Handling

By specifying test projects to exclude, I can skip tests that are either irrelevant to the current changes or temporarily disabled. This feature enhances control and reduces unnecessary processing.

### 5. Multi-Version .NET Support

The pipeline installs multiple .NET versions as specified in the `dotnetVersions` parameter, ensuring compatibility with various test projects.

### 6. Test Result Publishing

Test results are collected and published in the VSTest format, integrating seamlessly with Azure DevOps’ reporting tools.

## Scaling the Pipeline for Growth

### Efficient Handling of New Test Projects

As the monorepo grows:

- **Directory Structure Convention:** Adhering to a well-organized directory structure ensures that new test projects are automatically detected without additional configuration.
- **Depth Parameter Adjustment:** Increasing the `comparisonDepth` allows the pipeline to accommodate deeper directory hierarchies, ensuring scalability.

### Parameterized Flexibility

The modular design ensures that new requirements—such as additional .NET versions or exclusion of specific projects—can be incorporated without modifying the core logic. Simply update the parameters to adapt the pipeline to evolving needs.

### Reduced Resource Usage

By targeting only impacted tests, the pipeline reduces compute costs and accelerates feedback loops, enabling faster delivery cycles and efficient use of build agent resources.

### Team Collaboration

With clear logging and structured outputs, teams can easily identify which tests ran and why. This transparency fosters better collaboration and understanding across development and QA teams.

## Simplifying CI in Monorepos

Managing multiple solutions and test projects in a monorepo can be daunting. This Azure Pipeline simplifies the process by:

- Automating test selection based on changes.
- Reducing manual effort required to configure and manage tests.
- Streamlining integration with Azure DevOps tools for seamless CI workflows.

### Example Use Case

Imagine a monorepo with multiple microservices, each with its own test project. Previously, every commit triggered all tests, wasting time on unrelated areas. With this pipeline:

- I update one microservice.
- The pipeline detects the change, identifies the associated test project, and runs only those tests.
- Results are published, providing immediate feedback without redundant processing.

## Conclusion

This Azure Pipeline transforms CI for monorepos, making it scalable, efficient, and easy to manage. As more test projects are added, the pipeline’s dynamic nature ensures it remains performant and adaptable. By focusing on impacted tests, it reduces resource usage and accelerates development cycles, empowering teams to deliver high-quality software faster.

``` yaml
parameters:
  - name: comparisonBranch
    displayName: Comparison Branch. The branch to compare against to evaluate changes. Defaults to main
    type: string
    default: main
  - name: comparisonDepth
    displayName: Comparison Depth. Compares the top x folders to evaluate test projects to rerun
    type: number
    default: 2
  - name: buildConfiguration
    displayName: Build Configuration
    type: string
    default: debug
  - name: dotnetVersions
    displayName: Array of .NET versions required to run the tests. This should include all possible versions
    type: object
    default:
      - 8.0.x
  - name: excludedTestProjects
    displayName: Array of test projects to be excluded
    type: object
    default: []

steps:
  - checkout: self
    fetchDepth: 0

  - template: PrintEnvironmentVariables.azure-pipelines.yml

  - ${{each dv in parameters.dotnetVersions}}:
    - task: UseDotNet@2
      displayName: Install .NET ${{dv}}
      inputs:
        version: ${{dv}}

  - task: PowerShell@2
    displayName: Run affected tests
    inputs:
      pwsh: true
      targetType: inline
      informationPreference: continue
      script: |
        $InformationPreference = 'Continue'
        if ($env:SYSTEM_DEBUG)
        {
            $DebugPreference = 'Continue'
            $VerbosePreference = 'Continue'
        }

        $comparisonBranch = "${{parameters.comparisonBranch}}"
        Write-Verbose "comparisonBranch=$comparisonBranch"

        $currentDirPrefix = ".$([System.IO.Path]::DirectorySeparatorChar)"
        Write-Verbose "currentDirPrefix=$currentDirPrefix"
        
        Write-Debug "Getting changed files"
        $fileChanges = git diff --name-only "origin/$comparisonBranch..." |
          ForEach-Object {[System.IO.Path]::GetRelativePath(".", $_)}
        Write-Information "Found $($fileChanges.Count) changed files"
        Write-Verbose "fileChanges"
        $fileChanges | Write-Verbose

        $depthIndex = ${{parameters.comparisonDepth}} - 1 
        Write-Verbose "depthIndex=$depthIndex"

        Write-Debug "Getting changed directories"
        $dirChanges = $fileChanges | ForEach-Object {
            $split = $_.Split([System.IO.Path]::DirectorySeparatorChar)
            $dir = $split[0..$depthIndex] -join [System.IO.Path]::DirectorySeparatorChar
            return $dir
          } |
          Select-Object -Unique
        Write-Information "Found $($dirChanges.Count) changed directories"
        Write-Verbose "dirChanges"
        $dirChanges | Write-Verbose

        $xpathIsTestProject = "/Project/PropertyGroup/IsTestProject/text()"
        Write-Verbose "xpathIsTestProject=$xpathIsTestProject"

        function IsTestProject ([string]$Path) {
          $csproj = [xml](Get-Content -Path $Path)
          $IsTestProject = $csproj.SelectSingleNode("/Project/PropertyGroup/IsTestProject/text()").Value
          $HasTestSdk = $csproj.Project.ItemGroup.PackageReference.Include -icontains "Microsoft.NET.Test.Sdk"
          $HasMSTest = $csproj.Project.ItemGroup.PackageReference.Include -icontains "Microsoft.NET.Test.Sdk"
          $HasNUnit = $csproj.Project.ItemGroup.PackageReference.Include -icontains "NUnit"
          $HasXUnit = $csproj.Project.ItemGroup.PackageReference.Include -icontains "XUnit"

          return $IsTestProject -or $HasTestSdk -or $HasMSTest -or $HasNUnit -or $HasXUnit
        }
        
        Write-Debug "Getting all test projects"
        $testProjects = Get-ChildItem -Include "*.csproj" -Recurse |
          ForEach-Object {[System.IO.Path]::GetRelativePath(".", $_)} |
          Where-Object {IsTestProject -Path $_}
        Write-Verbose "allTestProjects"
        $testProjects | Write-Verbose

        function StartsWithAny ([string]$StringToCheck, [string[]] $Prefixes) {
            foreach ($prefix in $Prefixes) {
                if ($StringToCheck.StartsWith($prefix)) {
                    return $true
                }
            }
            return $false
        }
          
        Write-Debug "Filtering test projects to changed directories"
        $testProjects = $testProjects | Where-Object { StartsWithAny -StringToCheck $_ -Prefixes $dirChanges }

        $excludedTestProjectsJson = '${{ convertToJson(parameters.excludedTestProjects) }}'
        Write-Verbose "excludedTestProjectsJson=$excludedTestProjectsJson"

        Write-Debug "Resolving excluded tests"
        $excludedTestProjects = $excludedTestProjectsJson | 
          ConvertFrom-Json |
          ForEach-Object {[System.IO.Path]::GetRelativePath(".", $_)} |
          ForEach-Object {$_.Substring(2)}
        Write-Verbose "excludedTestProjects"
        $excludedTestProjects | Write-Verbose

        Write-Debug "Removing excluded test projects"
        $testProjects = $testProjects | Where-Object {$excludedTestProjects -notcontains $_}

        Write-Verbose "testProjects"
        $testProjects | Write-Verbose

        Write-Information "Running $($testProjects.Count) test projects"
        $testProjects | ForEach-Object {
          Write-Information "Running tests in $_"
          dotnet test $_ --configuration ${{parameters.buildConfiguration}} --collect "Code coverage" --logger trx --results-directory "$(Agent.TempDirectory)"
        }

  - task: PublishTestResults@2
    displayName: Publish Test Results
    inputs:
      buildConfiguration: ${{parameters.buildConfiguration}}
      testResultsFormat: VSTest
      testResultsFiles: $(Agent.TempDirectory)/**/*.trx
```