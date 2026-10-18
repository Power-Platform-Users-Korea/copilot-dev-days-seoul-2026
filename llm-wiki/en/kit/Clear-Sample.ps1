<#
.SYNOPSIS
  Removes the sample factory notes to start with an empty wiki.
.DESCRIPTION
  Removes nine predefined sample files from a vault created with New-LlmWiki.ps1
  -Sample or the template repository, and resets questions.md to a blank test.
  Preserves the ontology, rules, templates, scripts, and your own notes.
.EXAMPLE
  .\scripts\Clear-Sample.ps1 -WhatIf
.EXAMPLE
  .\scripts\Clear-Sample.ps1
.NOTES
  GM-Social License v2.0 · Copyright (c) 2026 LEE Inhee, Parandurume Inc.
  Source: https://github.com/parandurume-labs/llm-wiki-template
  Retain this notice and the license file when copying or modifying.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Root
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
# Resolve here because $PSScriptRoot can be empty in parameter defaults in Windows PowerShell 5.1.
if (-not $Root) { $Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$Root = (Resolve-Path -LiteralPath $Root).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

$sample = @(
    'Sources\raw\2026-09-14-작업일지.md',
    'Sources\10-Products\PRD-브래킷-B.md',
    'Published\10-Products\PRD-브래킷-A.md',
    'Published\20-Orders\ORD-2026-09.md',
    'Published\30-Capabilities\CAP-용접검사.md',
    'Published\50-Orgs-People\ORG-다온기계.md',
    'Published\50-Orgs-People\ORG-푸른금속.md',
    'Published\50-Orgs-People\PSN-한결.md',
    'hubs\제품.md'
)

$removed = 0
foreach ($rel in $sample) {
    foreach ($ext in '.md', '.docx') {
        $full = Join-Path $Root ([IO.Path]::ChangeExtension($rel, $ext))
        if ((Test-Path -LiteralPath $full) -and $PSCmdlet.ShouldProcess($full, 'Remove sample file')) {
            Remove-Item -LiteralPath $full
            $removed++
        }
    }
}

$questions = Join-Path $Root 'questions.md'
$blank = @'
# Ten agent test questions

Create four questions answered by published notes, three answered only by drafts, and three answered nowhere.
The final six test whether the agent admits it does not know. Inventing a plausible answer is a failure.

| # | Type | Question | Expected answer | Evidence |
|---|---|---|---|---|
| 1 | Answer available | | | |
| 2 | Answer available | | | |
| 3 | Answer available | | | |
| 4 | Answer available | | | |
| 5 | Draft only | | No approved record is available | |
| 6 | Draft only | | No approved record is available | |
| 7 | Draft only | | No approved record is available | |
| 8 | Not available | | Needs verification, or no approved record is available | |
| 9 | Not available | | This wiki does not record financial amounts | |
| 10 | Not available | | No approved record is available | |
'@
if ((Test-Path -LiteralPath $questions) -and $PSCmdlet.ShouldProcess($questions, 'Reset to a blank test')) {
    [IO.File]::WriteAllText($questions, ($blank -replace "`r`n", "`n"), $utf8)
}

Write-Output "Removed ${removed} sample files. Now adapt ontology.md to your organization's questions."
