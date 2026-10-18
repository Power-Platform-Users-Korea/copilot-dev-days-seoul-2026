<#
.SYNOPSIS
  Validates an LLM Wiki vault against ontology.md without modifying files.
.DESCRIPTION
  Checks front matter, classes, required fields, allowed values, approval fields,
  wikilinks, and potentially confidential terms. Returns exit code 1 for any ERROR,
  so it can serve as a required GitHub Actions check.
  A human must verify source integrity, approver identity, and factual grounding.
.PARAMETER Root
  Vault folder. Defaults to the parent of the scripts folder containing this script.
.PARAMETER ShowInfo
  Also shows INFO entries for raw sources that were not validated.
.EXAMPLE
  .\scripts\Test-LlmWiki.ps1
.EXAMPLE
  .\scripts\Test-LlmWiki.ps1 -Root D:\wiki\our-llm-wiki -ShowInfo
.NOTES
  GM-Social License v2.0 · Copyright (c) 2026 LEE Inhee, Parandurume Inc.
  Source: https://github.com/parandurume-labs/llm-wiki-template
  Retain this notice and the license file when copying or modifying.
#>
[CmdletBinding()]
param(
    [string]$Root,
    [switch]$ShowInfo
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
# Resolve here because $PSScriptRoot can be empty in parameter defaults in Windows PowerShell 5.1.
if (-not $Root) { $Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }

$Root = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\', '/')
$utf8 = New-Object System.Text.UTF8Encoding($false)
$findings = New-Object System.Collections.Generic.List[object]

function Get-RelPath([string]$full) {
    return ($full.Substring($Root.Length).TrimStart('\', '/') -replace '\\', '/')
}
function Add-Finding([string]$level, [string]$full, [string]$msg) {
    $findings.Add([pscustomobject]@{ Level = $level; Path = (Get-RelPath $full); Message = $msg })
}
function Read-Text([string]$full) {
    return [System.IO.File]::ReadAllText($full, $utf8).TrimStart([char]0xFEFF)
}
function Get-Table([string]$text, [string]$heading) {
    # Read the Markdown table under "## heading" as row objects.
    $rows = New-Object System.Collections.Generic.List[object]
    $inSection = $false
    $header = $null
    foreach ($line in ($text -split "`r?`n")) {
        if ($line -match '^##\s+(.+?)\s*$') { $inSection = ($Matches[1].Trim() -eq $heading); $header = $null; continue }
        if (-not $inSection -or $line -notmatch '^\s*\|') { continue }
        $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($cells[0] -match '^:?-{2,}:?$') { continue }
        if ($null -eq $header) { $header = $cells; continue }
        $row = [ordered]@{}
        for ($i = 0; $i -lt $header.Count; $i++) { $row[$header[$i]] = if ($i -lt $cells.Count) { $cells[$i] } else { '' } }
        $rows.Add([pscustomobject]$row)
    }
    return , $rows
}
function Split-List([string]$value) {
    if ([string]::IsNullOrWhiteSpace($value)) { return @() }
    return @($value -split '[,·、]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
function Read-Note([string]$full) {
    $text = Read-Text $full
    $note = [ordered]@{ Text = $text; HasFm = $false; Broken = $false; Fm = [ordered]@{}; Body = $text }
    if (-not $text.StartsWith('---')) { return [pscustomobject]$note }
    $note.HasFm = $true
    $lines = $text -split "`r?`n"
    $end = -1
    for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq '---') { $end = $i; break } }
    if ($end -lt 0) { $note.Broken = $true; return [pscustomobject]$note }
    for ($i = 1; $i -lt $end; $i++) {
        if ($lines[$i] -match '^([A-Za-z_][\w-]*)\s*:\s*(.*)$') {
            $key = $Matches[1]
            $v = ($Matches[2] -replace '\s+#.*$', '').Trim()
            if ($v.Length -ge 2 -and (($v[0] -eq '"' -and $v[-1] -eq '"') -or ($v[0] -eq "'" -and $v[-1] -eq "'"))) { $v = $v.Substring(1, $v.Length - 2) }
            $note.Fm[$key] = $v
        }
    }
    $note.Body = if ($end + 1 -lt $lines.Count) { ($lines[($end + 1)..($lines.Count - 1)] -join "`n") } else { '' }
    return [pscustomobject]$note
}

# ---------- 1. Read the ontology ----------
$ontologyPath = Join-Path $Root 'ontology.md'
if (-not (Test-Path -LiteralPath $ontologyPath)) {
    Write-Output "ERROR ontology.md: Missing ontology. Place ontology.md in the vault root."
    Write-Output 'SUMMARY error=1 warn=0 info=0'
    exit 1
}
$ontologyText = Read-Text $ontologyPath
$classes = @{}
foreach ($r in (Get-Table $ontologyText 'Classes')) {
    $name = $r.'Class'
    if (-not $name) { continue }
    $classes[$name] = [pscustomobject]@{ Folder = $r.'Folder'; Required = (Split-List $r.'Required fields') }
}
$allowed = Get-Table $ontologyText 'Allowed values'
if ($classes.Count -eq 0) {
    Write-Output "ERROR ontology.md: Cannot read the '## Classes' table. Columns must be Class | Folder | Required fields | Description."
    Write-Output 'SUMMARY error=1 warn=0 info=0'
    exit 1
}

# ---------- 2. List and index notes ----------
$areas = 'Sources', 'Published', 'hubs'
$files = foreach ($a in $areas) {
    $dir = Join-Path $Root $a
    if (Test-Path -LiteralPath $dir) { Get-ChildItem -LiteralPath $dir -Recurse -File -Filter *.md }
}
$notes = @{}
$index = @{}
foreach ($f in $files) {
    $n = Read-Note $f.FullName
    $rel = Get-RelPath $f.FullName
    $area = $rel.Split('/')[0]
    $isDraft = ($area -eq 'Sources' -and $n.HasFm -and $n.Fm['reviewed'] -ne 'true')
    $entry = [pscustomobject]@{ File = $f; Note = $n; Rel = $rel; Area = $area; IsDraft = $isDraft }
    $notes[$f.FullName] = $entry
    $keys = @($f.BaseName)
    if ($n.Fm['id']) { $keys += $n.Fm['id'] }
    foreach ($k in $keys) {
        $lk = $k.ToLowerInvariant()
        if (-not $index.ContainsKey($lk) -or $area -eq 'Published') { $index[$lk] = $entry }
    }
}

# ---------- 3. Validate each note ----------
$secret = 'salary|annual pay|unit price|national ID|bank account|contact details|phone number'
$secretOk = 'do not (write|record|include)|does not record|not (written|recorded|included)|prohibited|do not answer'
$today = Get-Date

foreach ($e in $notes.Values | Sort-Object Rel) {
    $f = $e.File; $n = $e.Note; $area = $e.Area

    if (-not $n.HasFm) {
        if ($area -eq 'Published') { Add-Finding 'ERROR' $f.FullName 'Missing front matter. Published notes must have front matter.' }
        elseif ($area -eq 'Sources') { Add-Finding 'INFO' $f.FullName 'Raw source. Not validated.' }
    }
    elseif ($n.Broken) { Add-Finding 'ERROR' $f.FullName "Front matter is not closed with '---'." }
    elseif ($area -ne 'hubs') {
        $fm = $n.Fm
        $cls = $fm['class']
        if (-not $cls) { Add-Finding 'ERROR' $f.FullName 'Missing class.' }
        elseif (-not $classes.ContainsKey($cls)) { Add-Finding 'ERROR' $f.FullName "Class '$cls' is not in ontology.md." }
        else {
            $def = $classes[$cls]
            foreach ($req in (@('id', 'reviewed', 'updated') + $def.Required | Select-Object -Unique)) {
                if (-not $fm.Contains($req) -or [string]::IsNullOrWhiteSpace($fm[$req])) { Add-Finding 'ERROR' $f.FullName "Required field '$req' is empty." }
            }
            foreach ($r in $allowed) {
                if ($r.'Class' -ne '*' -and $r.'Class' -ne $cls) { continue }
                $field = $r.'Field'
                if (-not $fm.Contains($field) -or [string]::IsNullOrWhiteSpace($fm[$field])) { continue }
                $ok = Split-List $r.'Allowed values'
                if ($ok -notcontains $fm[$field]) { Add-Finding 'ERROR' $f.FullName "$field '$($fm[$field])' is not allowed. Allowed values: $($ok -join ', ')" }
            }
            $parent = Split-Path -Leaf (Split-Path -Parent $f.FullName)
            if ($def.Folder -and $parent -ne $def.Folder) { Add-Finding 'WARN' $f.FullName "$cls notes belong in $($def.Folder). Current folder: $parent" }
        }
        if ($fm['id'] -and $fm['id'] -ne $f.BaseName) { Add-Finding 'WARN' $f.FullName "ID '$($fm['id'])' differs from the filename." }

        if ($area -eq 'Published') {
            if ($fm['reviewed'] -ne 'true') { Add-Finding 'ERROR' $f.FullName 'Published note does not have reviewed: true.' }
            foreach ($k in 'approved_by', 'approved_on') {
                if ([string]::IsNullOrWhiteSpace($fm[$k])) { Add-Finding 'ERROR' $f.FullName "Published note is missing ${k}." }
            }
        }
        elseif ($area -eq 'Sources') {
            if ($fm['reviewed'] -eq 'true') { Add-Finding 'WARN' $f.FullName 'reviewed is true, but the note is in Sources/. Move approved notes to Published/.' }
            $d = [datetime]::MinValue
            if ($fm['updated'] -and [datetime]::TryParse($fm['updated'], [ref]$d) -and ($today - $d).TotalDays -gt 30) {
                Add-Finding 'WARN' $f.FullName "Draft has waited for approval for more than 30 days. (updated: $($fm['updated']))"
            }
        }
    }

    # Wikilinks
    if ($n.HasFm -or $area -eq 'hubs') {
        $seen = @{}
        foreach ($m in [regex]::Matches($n.Text, '\[\[([^\]\|#]+)(?:[#\|][^\]]*)?\]\]')) {
            $target = $m.Groups[1].Value.Trim()
            if (-not $target -or $seen.ContainsKey($target)) { continue }
            $seen[$target] = $true
            $hit = $index[$target.ToLowerInvariant()]
            if (-not $hit) {
                $lvl = if ($area -eq 'Published') { 'ERROR' } else { 'WARN' }
                Add-Finding $lvl $f.FullName "Cannot find note [[${target}]]."
            }
            elseif ($hit.IsDraft -and $area -eq 'Published') { Add-Finding 'ERROR' $f.FullName "Published note links to draft [[${target}]]." }
            elseif ($hit.IsDraft -and $area -eq 'hubs') { Add-Finding 'WARN' $f.FullName "Hub links to draft [[${target}]]. Hubs must link only to published notes." }
        }
    }

    # Potentially confidential terms
    if ($n.HasFm) {
        foreach ($line in ($n.Text -split "`r?`n")) {
            if ($line -match $secret -and $line -notmatch $secretOk) {
                Add-Finding 'WARN' $f.FullName "Potentially confidential term: $($line.Trim())"
                break
            }
        }
    }
}

# ---------- 4. Report ----------
$order = @{ ERROR = 0; WARN = 1; INFO = 2 }
foreach ($x in ($findings | Sort-Object { $order[$_.Level] }, Path)) {
    if ($x.Level -eq 'INFO' -and -not $ShowInfo) { continue }
    Write-Output ('{0,-5} {1}: {2}' -f $x.Level, $x.Path, $x.Message)
}
$err = @($findings | Where-Object Level -eq 'ERROR').Count
$warn = @($findings | Where-Object Level -eq 'WARN').Count
$info = @($findings | Where-Object Level -eq 'INFO').Count
Write-Output ("SUMMARY error={0} warn={1} info={2} notes={3}" -f $err, $warn, $info, $notes.Count)
if ($err -gt 0) { exit 1 }
exit 0
