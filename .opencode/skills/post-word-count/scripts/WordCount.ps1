<#
.SYNOPSIS
    Approximates the word count and read time Minimal Mistakes prints for a post.

.DESCRIPTION
    The theme renders the page, then applies `strip_html | number_of_words` and
    divides by `words_per_minute` (200). This replicates that closely enough to
    budget against: it drops the frontmatter, HTML comments, image syntax and
    link targets, keeps the text inside code fences but drops the fence lines,
    and removes markdown markers that do not appear in the rendered page.

    Under 200 words the theme prints "less than 1 minute read"; at exactly 200 it
    prints "1 minute read"; otherwise it prints the floor of words / 200.

.PARAMETER Path
    One or more post or draft paths.

.EXAMPLE
    pwsh .opencode/scripts/WordCount.ps1 _drafts/2026-01-01-example.md

.EXAMPLE
    pwsh .opencode/scripts/WordCount.ps1 _posts/*.md
#>
[CmdletBinding()]
param (
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]] $Path = @()
)

$ErrorActionPreference = 'Stop'

if ($Path.Count -eq 0) {
    throw 'Usage: WordCount.ps1 <file> [more files]'
}

$wordsPerMinute = 200
$fence = [string][char]96 + [char]96 + [char]96

$targets = foreach ($item in $Path) {
    $resolved = Resolve-Path -Path $item -ErrorAction SilentlyContinue
    if (-not $resolved) {
        Write-Error "No match: $item" -ErrorAction Continue
        continue
    }

    foreach ($candidate in $resolved) {
        if (Test-Path -Path $candidate.Path -PathType Leaf) {
            $candidate.Path
        }
        else {
            Write-Error "Not a file: $($candidate.Path)" -ErrorAction Continue
        }
    }
}

if (-not $targets) {
    throw 'No files matched.'
}

foreach ($file in $targets) {
    $text = Get-Content -Path $file -Raw

    # Frontmatter, delimited by the first pair of --- lines.
    $text = $text -replace '(?ms)\A---\r?\n.*?\r?\n---\r?\n', ''

    # Keep code block bodies, drop the opening fence line and the closing fence.
    $text = [regex]::Replace($text, '(?m)^' + $fence + '[^\r\n]*\r?\n', ' ')
    $text = $text -replace ('(?m)^' + $fence + '\s*$'), ' '

    # HTML comments carry no rendered text.
    $text = [regex]::Replace($text, '(?s)<!--.*?-->', ' ')

    # Images contribute only their alt attribute in HTML, so drop them whole.
    $text = [regex]::Replace($text, '!\[[^\]]*\]\([^)]*\)', ' ')

    # Links contribute their label but not their target.
    $text = [regex]::Replace($text, '\[([^\]]*)\]\([^)]*\)', '$1')

    # Markdown markers that are absent from the rendered page.
    $text = $text -replace '[*_`>#]', ' '
    $text = $text -replace '(?m)^\s*[-+]\s', ' '

    $words = ($text -split '\s+').Where({ $_ -ne '' }).Count

    $readTime = if ($words -lt $wordsPerMinute) {
        'less than 1 minute read'
    }
    elseif ($words -eq $wordsPerMinute) {
        '1 minute read'
    }
    else {
        "$([int][math]::Floor($words / $wordsPerMinute)) minute read"
    }

    [pscustomobject]@{
        Words    = $words
        ReadTime = $readTime
        Path     = $file
    }
}
