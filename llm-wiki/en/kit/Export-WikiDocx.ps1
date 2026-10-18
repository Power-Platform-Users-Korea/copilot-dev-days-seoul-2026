<#
.SYNOPSIS
  Creates a matching .docx for each approved Markdown note in Published/.
.DESCRIPTION
  Copilot Studio SharePoint knowledge currently reads .docx bodies but not .md bodies.
  Uses Word on Windows: front matter becomes a two-column table, # headings become
  Word heading styles, and other lines become paragraphs. Wikilinks retain only their labels.
  Targets Published/ only. Exporting drafts in Sources/ would bypass the approval gate.
.PARAMETER Root
  Vault folder. Defaults to the parent of the scripts folder containing this script.
.PARAMETER Force
  Recreates .docx files even when newer than their matching .md files.
.PARAMETER Prune
  Removes .docx files whose .md counterpart no longer exists, so agents cannot keep
  citing notes removed from the approved collection.
.EXAMPLE
  .\scripts\Export-WikiDocx.ps1 -Prune
.NOTES
  GM-Social License v2.0 · Copyright (c) 2026 LEE Inhee, Parandurume Inc.
  Source: https://github.com/parandurume-labs/llm-wiki-template
  Retain this notice and the license file when copying or modifying.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Root,
    [switch]$Force,
    [switch]$Prune
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
# Resolve here because $PSScriptRoot can be empty in parameter defaults in Windows PowerShell 5.1.
if (-not $Root) { $Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }

$pub = Join-Path (Resolve-Path -LiteralPath $Root).Path 'Published'
if (-not (Test-Path -LiteralPath $pub)) { throw "Published folder not found: $pub" }
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Remove-WikiLink([string]$s) {
    return [regex]::Replace($s, '\[\[([^\]\|]+)(?:\|([^\]]+))?\]\]', { param($m) if ($m.Groups[2].Success) { $m.Groups[2].Value } else { $m.Groups[1].Value } })
}

$mdFiles = @(Get-ChildItem -LiteralPath $pub -Recurse -File -Filter *.md)
$todo = @($mdFiles | Where-Object {
        $docx = [IO.Path]::ChangeExtension($_.FullName, '.docx')
        $Force -or -not (Test-Path -LiteralPath $docx) -or ((Get-Item -LiteralPath $docx).LastWriteTime -lt $_.LastWriteTime)
    })
Write-Output ("Exporting {1} of {0} approved notes to .docx." -f $mdFiles.Count, $todo.Count)

if ($todo.Count -gt 0 -and $PSCmdlet.ShouldProcess("$($todo.Count) notes", 'Create .docx files with Word')) {
    try { $word = New-Object -ComObject Word.Application }
    catch { throw 'Word was not found. Run on a Windows PC with Word installed, or paste each note into Word and save it as a .docx with the same name.' }
    $word.Visible = $false
    $word.DisplayAlerts = 0
    try {
        foreach ($md in $todo) {
            $text = [IO.File]::ReadAllText($md.FullName, $utf8).TrimStart([char]0xFEFF)
            $lines = $text -split "`r?`n"
            $fm = New-Object System.Collections.Generic.List[object]
            $start = 0
            if ($lines.Count -gt 0 -and $lines[0].Trim() -eq '---') {
                for ($i = 1; $i -lt $lines.Count; $i++) {
                    if ($lines[$i].Trim() -eq '---') { $start = $i + 1; break }
                    if ($lines[$i] -match '^([A-Za-z_][\w-]*)\s*:\s*(.*)$') { $fm.Add(@($Matches[1], (Remove-WikiLink ($Matches[2].Trim().Trim('"'))))) }
                }
            }
            $doc = $word.Documents.Add()
            $sel = $word.Selection
            if ($fm.Count -gt 0) {
                $table = $doc.Tables.Add($sel.Range, $fm.Count, 2)
                $table.Borders.Enable = $true
                for ($r = 0; $r -lt $fm.Count; $r++) {
                    $table.Cell($r + 1, 1).Range.Text = $fm[$r][0]
                    $table.Cell($r + 1, 2).Range.Text = $fm[$r][1]
                }
                $sel.EndKey(6) | Out-Null   # End of document
                $sel.TypeParagraph()
            }
            for ($i = $start; $i -lt $lines.Count; $i++) {
                $line = $lines[$i]
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                if ($line -match '^(#{1,3})\s+(.*)$') {
                    $sel.Style = $doc.Styles.Item(-1 - $Matches[1].Length)   # wdStyleHeading1..3
                    $sel.TypeText((Remove-WikiLink $Matches[2]))
                }
                else {
                    $sel.Style = $doc.Styles.Item(-1)                        # wdStyleNormal
                    $sel.TypeText((Remove-WikiLink ($line -replace '\*\*', '')))
                }
                $sel.TypeParagraph()
            }
            $out = [IO.Path]::ChangeExtension($md.FullName, '.docx')
            $doc.SaveAs2($out, 16)   # wdFormatDocumentDefault
            $doc.Close(0)
            Write-Output ("  Created  {0}" -f ($out.Substring($pub.Length).TrimStart('\') -replace '\\', '/'))
        }
    }
    finally {
        $word.Quit()
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($word)
    }
}

if ($Prune) {
    foreach ($d in Get-ChildItem -LiteralPath $pub -Recurse -File -Filter *.docx) {
        if ($d.Name.StartsWith('~$')) { continue }
        if (-not (Test-Path -LiteralPath ([IO.Path]::ChangeExtension($d.FullName, '.md')))) {
            if ($PSCmdlet.ShouldProcess($d.FullName, 'Remove orphaned .docx')) {
                Remove-Item -LiteralPath $d.FullName
                Write-Output ("  Removed  {0}" -f $d.Name)
            }
        }
    }
}
Write-Output 'Done. When Published/ on SharePoint contains both .md and .docx files, Copilot Studio cites the .docx files.'
