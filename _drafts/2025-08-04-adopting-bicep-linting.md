---
title: Adopting Bicep Linting
category: Azure
tags:
    - Bicep
    - Bicep Modules
    - ARM
    - Azure
    - IaC
    - Linting
    - Dotnet Too
    - Spectre Console
---

In **[one of my earlier posts]({% post_url 2023-03-13-sharing-bicep-templates %})**, I covered using **[ARM-TTK](https://github.com/Azure/arm-ttk)** via an **[Azure DevOps extension](https://marketplace.visualstudio.com/items?itemName=Sam-Cogan.ARMTTKExtensionXPlatform)** to analyse and test my Bicep modules automatically as part of my pipelines. Since then, Microsoft now offers a 1st party solution for **[Bicep linting](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/linter)** which aligns more directly with Bicep and opens the possibility for the linting to be easily adapted to other CI/CD platforms.

My goal was to replace using the DevOps Extension with the Bicep linter. For this post, I want to share my approach to this. As a sneak peak, this project turned out to be an opportunity to use library I've wanted to use for a while....**[Spectre.Console](https://spectreconsole.net/)**!

## What Does Linting Look Like?

The **[VS Code Bicep extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep)** offers great intellisense for developing Bicep templates, giving clear warning in the code.

![image1](/images/adopting-bicep-linting/image1.png)

However, the addition of the **[`az bicep lint`](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-cli#lint)** command, allows verifying Bicep templates against the same rules used in the IDE. Running the command against the Bicep in the earlier screenshot produces the results below:

```bash
> az bicep lint --file main.bicep
WARNING: D:\Git\milkyware\azure-bicep\.tmp\storageaccount.bicep(22,35) : Warning outputs-should-not-contain-secrets: Outputs should not contain secrets. Found possible secret: function 'listKeys' [https://aka.ms/bicep/linter-diagnostics#outputs-should-not-contain-secrets]
```

The default console shows the same violation as before, but the format doesn't help from an automation perspective. To deal with that, there is the `--diagnostics-format` which currently supports **Static Analysis Results Interchange Format (SARIF)**.

```json
> az bicep lint --file main.bicep --diagnostics-format sarif
{
  "$schema": "https://schemastore.azurewebsites.net/schemas/json/sarif-2.1.0-rtm.6.json",
  "version": "2.1.0",
  "runs": [
    {
      "tool": {
        "driver": {
          "name": "bicep"
        }
      },
      "results": [
        {
          "ruleId": "outputs-should-not-contain-secrets",
          "message": {
            "text": "Outputs should not contain secrets. Found possible secret: function 'listKeys' [https://aka.ms/bicep/linter-diagnostics#outputs-should-not-contain-secrets]"
          },
          "locations": [
            {
              "physicalLocation": {
                "artifactLocation": {
                  "uri": "file:///D:/Git/.tmp/main.bicep"
                },
                "region": {
                  "startLine": 22,
                  "charOffset": 35
                }
              }
            }
          ]
        }
      ],
      "columnKind": "utf16CodeUnits"
    }
  ]
}
```

SARIF is a widely used, standardised format for sharing static code analysis results. Let's have a look at how we can integrate that with a pipeline.

## Replacing ARM-TTK in my Pipelines

Previously, I've been using the **Sam-Cogan.ARMTTKExtensionXPlatform** DevOps Extension, which is a wrapper around **ARM-TTK**. This extension performs the code analysis and then outputs the results as **NUnit 2** which can then be published to DevOps. When the results are published, if they include any failures, this fails the pipeline which raises awareness of violations.

However, currently, the `PublishTestResults@2` task doesn't support publishing SARIF results, so the next step is to reformat the results.

### Developing a SARIF Converter

In a few blog posts, I'd seen suggestions of using the **[sarif-junit npm package](https://www.npmjs.com/package/sarif-junit)** to convert the SARIF to **[JUnit](https://junit.org/)** which is supported by the `PublishTestResults@2` task. However, I found that the resulting format wasn't quite what I wanted, so I decided to develop my own converter.

To do that, I decided this was a good opportunity to try out **[Spectre.Console](https://spectreconsole.net/)**. As a brief introduction, **Spectre.Console** is a library for building rich, command-line apps (it also supports ANSI widgets for displaying data).

```cs
var sarif = SarifLog.Load(@"path\to\file.sarif")
```

Microsoft provide a **[`SARIF Nuget package`](https://www.nuget.org/packages/Sarif.Sdk/)** for parsing and interacting with results data.

```cs
public interface ISarifConverter
{
    public FormatType FormatType { get; }

    Task<string> ConvertAsync(SarifLog sarif);
}

public class JUnitConverter(ILogger<JUnitConverter> logger) : ISarifConverter
{
    private readonly ILogger<JUnitConverter> _logger = logger;

    public FormatType FormatType => FormatType.JUnit;

    public async Task<string> ConvertAsync(SarifLog sarif)
    {
        _logger.LogInformation("Converting SARIF to JUnit");
        // Building JUnit XML according to schema
        return xml;
    }
}
```

I started by creating a simple converter interface and service which would use the `SarifLog` object to build up the JUnit XML.

```cs
public enum FormatType
{
    JUnit,
    NUnit
}

public class ConvertSarifSettings : LoggingSettings
{
    [CommandOption("-f|--format")]
    [Description("Format to convert SARIF to. Allowed values: JUnit, NUnit")]
    public FormatType FormatType { get; set; } = FormatType.JUnit;

    [CommandOption("-i|--input-file")]
    [Description("Path to the input SARIF file")]
    public string? InputFile { get; set; }

    [CommandOption("-o|--output-file")]
    [Description("Path to output the converted file to. Outputs to stdout if not specified")]
    public string? OutputFile { get; set; }
}
```

I then created a **[settings class](https://spectreconsole.net/cli/settings)** to provide arguments which could be passed into my tool. Spectre.Console offers support for using attributes to indicate the corresponding command argument and documentation.

```cs
public class ConvertSarifCommand(ILogger<ConvertSarifCommand> logger, IAnsiConsole ansiConsole, IEnumerable<ISarifConverter> converters) : AsyncCommand<ConvertSarifSettings>
{
    private readonly IAnsiConsole _ansiConsole = ansiConsole;
    private readonly IEnumerable<ISarifConverter> _converters = converters;
    private readonly ILogger<ConvertSarifCommand> _logger = logger;

    public override async Task<int> ExecuteAsync(CommandContext context, ConvertSarifSettings settings)
    {
        var sarif = SarifLog.Load(settings.InputFile);

        var converter = _converters.FirstOrDefault(c => c.FormatType == settings.FormatType);
        if (converter == null)
        {
            _logger.LogError("Unsupported output type");
            return 1;
        }

        var xml = await converter.ConvertAsync(sarif);

        if (string.IsNullOrEmpty(settings.OutputFile))
        {
            _ansiConsole.Write(xml);
            return 0;
        }

        var directory = Path.GetDirectoryName(settings.OutputFile);
        if (!string.IsNullOrEmpty(directory))
        {
            Directory.CreateDirectory(directory);
        }

        await File.WriteAllTextAsync(settings.OutputFile, xml);
        return 0;
    }
}
```

I then implemented an **[`AsyncCommand<T>`](https://spectreconsole.net/cli/commands)** in my `ConvertSarifCommand`, using the values from the `settings` argument to control where to read and write files.

**N.B.** Notice that dependencies are **injected into the command**, ready for Dependency Injection (DI)

```cs
var services = new ServiceCollection();
// Register DI services

var registrar = new TypeRegistrar(services);
var app = new CommandApp<ConvertSarifCommand>(registrar);
app.Configure(configure =>
{
    configure.SetApplicationName("milkyware-sarif-converter");
    configure.UseAssemblyInformationalVersion();
    configure.AddExample("-i", @"./test.sarif.json", "-f", "JUnit")
        .AddExample("-i", @"./test.sarif.json", "-o", "./test.xml", "-f", "JUnit");

#if DEBUG
    configure.PropagateExceptions();
    configure.ValidateExamples();
#endif
});

app.Run(args);
```

Lastly, I setup the `CommandApp` to bring all of these components together. The `CommandApp` is similar to the `HostBuilder` of ASP.NET Core in terms of registering services services and dependencies followed by configuring the app. Spectre.Console provides some **[fantastic documentation](https://spectreconsole.net/cli/commandapp)** for setting this up rather than me repeating it here.

To make this tool available to use in my pipelines, I've published it to **[NuGet](https://www.nuget.org/packages/milkyware-sarif-converter)** as a dotnet tool.

```sh
dotnet tool install milkyware-sarif-converter -g
```

For more details on the tool, please refer to my repo.

[![milkyware/sarif-converter - GitHub](https://gh-card.dev/repos/milkyware/sarif-converter.svg)](https://github.com/milkyware/sarif-converter)

Next, let's integrate my new tool with my existing pipeline template.

### Integrating the Tool into the Pipelines

To start getting access to the tool in my DevOps pipeline, I need to setup the .NET SDK in my job.

<!-- {% raw %} -->
```yaml
- task: UseDotNet@2
  displayName: Install .Net Core
```
<!-- {% endraw %} -->

I can then use the same `dotnet tool install` command that we demonstrated earlier.

<!-- {% raw %} -->
```yaml
- task: PowerShell@2
  displayName: Install SARIF Converter
  inputs:
    pwsh: true
    targetType: inline
    script: |
    dotnet tool install -g milkyware-sarif-converter
```
<!-- {% endraw %} -->

`AzureCLI@2`

#### Complete Pipeline Template Sample

<!-- {% raw %} -->
```yaml
parameters:
  - name: azureSubscription
    displayName: Azure Subscription to restore private bicep modules
    type: string
  - name: bicepPath
    displayName: Path to the Bicep file to build
    type: string
  - name: comparisonBranch
    displayName: Comparison Branch. The branch to compare against to evaluate changes. Defaults to main
    type: string
    default: main
  - name: dependsOn
    displayName: Array of stages to depend on, defaults to no dependencies
    type: object
    default: []

stages:
  - stage: ScanBicep
    displayName: Scan Bicep
    dependsOn: ${{parameters.dependsOn}}
    jobs:
      - job: 
        pool:
          vmImage: ubuntu-latest
        variables:
          resultsDir: $(Agent.TempDirectory)/results
          sarifPath: ${{variables.resultsDir}}/bicep.sarif.json
        steps: 
          - checkout: self
            fetchDepth: 0

          - template: PrintEnvironmentVariables.azure-pipelines.yml

          - task: UseDotNet@2
            displayName: Install .Net Core

          - task: PowerShell@2
            displayName: Install SARIF Converter
            inputs:
              pwsh: true
              targetType: inline
              script: |
                dotnet tool install -g milkyware-sarif-converter
          
          - task: AzureCLI@2
            displayName: Scan Bicep
            inputs:
              azureSubscription: ${{parameters.azureSubscription}}
              visibleAzLogin: false
              useGlobalConfig: true
              scriptType: pscore
              scriptLocation: inlineScript
              inlineScript: |
                $InformationPreference = 'Continue'
                if ($env:SYSTEM_DEBUG)
                {
                    $DebugPreference = 'Continue'
                    $VerbosePreference = 'Continue'
                }

                # Workaround to fix AzureCLI task installing Bicep in wrong location
                Write-Debug "Installing Bicep CLI"
                az config set bicep.use_binary_from_path=false
                az bicep install

                Write-Debug "Creating results directory"
                $resultsDir = "${{variables.resultsDir}}"
                New-Item -Path $resultsDir -ItemType Directory | Out-Null
                
                $bicepPath = "${{parameters.bicepPath}}"
                Write-Verbose "bicepPath=$bicepPath"

                Write-Debug "Gathering Bicep files"
                $bicepFiles = Get-ChildItem -Path $bicepPath -Filter *.bicep -Recurse
                Write-Verbose "Found $($bicepFiles.Count) Bicep files"

                if (Test-Path -Path $bicepPath -PathType Container) {
                  Write-Debug "Filtering out unchanged files"
                  
                  $remoteName = "origin"

                  $comparisonBranch = "${{parameters.comparisonBranch}}"
                  Write-Verbose "comparisonBranch=$comparisonBranch"

                  Write-Debug "Getting current commit"
                  $currentCommit = git rev-parse HEAD
                  Write-Verbose "currentCommit=$currentCommit"
                  
                  Write-Debug "Getting comparison branch commit"
                  $comparisonCommit = git rev-parse "$remoteName/$comparisonBranch"
                  Write-Verbose "comparisonCommit=$comparisonCommit"

                  $repoPath = git rev-parse --show-toplevel
                  Write-Verbose "repoPath=$repoPath"

                  $fileChanges = git diff --name-only "$remoteName/$comparisonBranch..." |
                    ForEach-Object {[System.IO.FileInfo](Join-Path -Path $repoPath -ChildPath $_)}

                  Write-Debug "Comparing Bicep files with changes"
                  $comparedFiles = Compare-Object -ReferenceObject $bicepFiles -DifferenceObject $fileChanges `
                    -IncludeEqual `
                    -ExcludeDifferent

                  Write-Debug "Updating files to scan"
                  $bicepFiles = $comparedFiles | Select-Object -ExpandProperty InputObject
                }

                foreach ($bicepFile in $bicepFiles) {
                  Write-Information "Processing Bicep file: $($bicepFile.FullName)"

                  $tempPath = $null
                  try {
                    $tempPath = [System.IO.Path]::GetTempFileName()
                    Write-Verbose "tempPath=$tempPath"

                    Write-Debug "Linting Bicep"
                    az bicep lint --file $bicepFile.FullName --diagnostics-format sarif | Out-File -Path $tempPath -Encoding utf8

                    $resultsFile = "$($bicepFile.BaseName).junit.xml"
                    $resultsPath = Join-Path -Path $resultsDir -ChildPath $resultsFile
                    Write-Verbose "resultsPath=$resultsPath"

                    Write-Debug "Converting to JUnit"
                    milkyware-sarif-converter -i $tempPath -o $resultsPath
                    Write-Verbose (Get-Content -Path $resultsPath -Raw)
                  }
                  finally {
                    Remove-Item -Path $tempPath -ErrorAction Ignore
                  }
                }
              powerShellErrorActionPreference: Stop
            
          - task: PublishTestResults@2
            displayName: Publish Scan Results
            condition: succeededOrFailed()
            inputs:
              testResultsFormat: JUnit
              testResultsFiles: ${{variables.resultsDir}}/*.xml
              failTaskOnFailedTests: true

```
<!-- {% endraw %} -->

## Wrapping Up
