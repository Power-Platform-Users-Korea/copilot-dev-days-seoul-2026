<#
.SYNOPSIS
  Signs in to Microsoft 365 and uploads the vault to a SharePoint document library (Teams channel files).
.DESCRIPTION
  1. Installs Microsoft Graph PowerShell authentication for the current user if missing.
  2. Signs in with Connect-MgGraph. A human signs in and consents in the browser.
  3. Finds the site and library and uploads the vault, excluding .git, .github, and .obsidian.
  4. Provides the Published/ folder URL for Copilot Studio knowledge.
  Configure folder permissions (only approvers edit Published/) and the Copilot Studio
  agent manually. Instructions are printed at the end.
  Alternatively, select "Sync" or "Add shortcut to OneDrive" in Teams channel files
  and set New-LlmWiki.ps1 -Path to that synchronized folder. OneDrive uploads it.
  With -WhatIf, lists files without signing in or uploading.
.PARAMETER Path
  Vault folder.
.PARAMETER SiteUrl
  SharePoint site URL, e.g. https://contoso.sharepoint.com/sites/wiki-team.
  Select "Open in SharePoint" in the Teams channel Files tab to find it.
.PARAMETER Folder
  Vault folder path within the library. For a standard Teams channel, use
  "channel-name/vault-name". Defaults to the vault folder name.
.PARAMETER Library
  Document library name. Defaults to the site's default library (Documents, Shared Documents).
.PARAMETER ExportDocx
  Runs Export-WikiDocx.ps1 to create approved .docx counterparts before uploading.
.EXAMPLE
  .\scripts\Publish-LlmWikiSharePoint.ps1 -Path . -SiteUrl https://contoso.sharepoint.com/sites/wiki-team -Folder "Wiki/our-llm-wiki" -WhatIf
.EXAMPLE
  .\scripts\Publish-LlmWikiSharePoint.ps1 -Path . -SiteUrl https://contoso.sharepoint.com/sites/wiki-team -Folder "Wiki/our-llm-wiki" -ExportDocx
.NOTES
  GM-Social License v2.0 · Copyright (c) 2026 LEE Inhee, Parandurume Inc.
  Source: https://github.com/parandurume-labs/llm-wiki-template
  Retain this notice and the license file when copying or modifying.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$SiteUrl,
    [string]$Folder,
    [string]$Library,
    [switch]$ExportDocx
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
function Step([string]$msg) { Write-Output ''; Write-Output "== $msg" }
function Get-EncodedPath([string]$p) { return (($p -replace '\\', '/').Trim('/').Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/' }

$Path = (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\')
if (-not (Test-Path -LiteralPath (Join-Path $Path 'ontology.md'))) { throw "Not a vault folder (ontology.md missing): $Path" }
if (-not $Folder) { $Folder = Split-Path -Leaf $Path }
$site = [uri]$SiteUrl
$graph = 'https://graph.microsoft.com/v1.0'

# ---------- 0. .docx counterparts ----------
if ($ExportDocx) {
    Step '0. Create .docx counterparts for approved notes'
    $exporter = Join-Path $Path 'scripts\Export-WikiDocx.ps1'
    if ($PSCmdlet.ShouldProcess($Path, 'Run Export-WikiDocx.ps1')) { & $exporter -Root $Path -Prune }
}

# ---------- 1. Files to upload ----------
Step '1. Select files to upload'
$skip = '\\(\.git|\.github|\.obsidian|\.vscode)(\\|$)'
$files = @(Get-ChildItem -LiteralPath $Path -Recurse -File | Where-Object { $_.FullName -notmatch $skip -and -not $_.Name.StartsWith('~$') -and $_.Name -ne '.gitkeep' })
$big = @($files | Where-Object { $_.Length -gt 250MB })
if ($big.Count -gt 0) { throw "Files larger than 250MB will not be uploaded: $($big.Name -join ', ')" }
Write-Output ("   {0} files → folder '{2}' at {1}" -f $files.Count, $SiteUrl, $Folder)

if ($WhatIfPreference) {
    $files | Select-Object -First 15 | ForEach-Object { Write-Output ('   ' + ($_.FullName.Substring($Path.Length + 1) -replace '\\', '/')) }
    if ($files.Count -gt 15) { Write-Output "   … and $($files.Count - 15) more" }
    Write-Output ''
    Write-Output '   -WhatIf: did not sign in or upload anything.'
    return
}

# ---------- 2. Sign in ----------
Step '2. Sign in to Microsoft 365'
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Write-Output '   Installing Microsoft.Graph.Authentication for the current user.'
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force -AllowClobber
}
Import-Module Microsoft.Graph.Authentication
Write-Output '   Sign in directly with your work account when the browser opens. First-time use requires consent.'
Connect-MgGraph -Scopes 'Sites.ReadWrite.All' -NoWelcome
Write-Output ("   Signed in: {0}" -f (Get-MgContext).Account)

# ---------- 3. Site and library ----------
Step '3. Find the site and document library'
$siteObj = Invoke-MgGraphRequest -Method GET -Uri ("$graph/sites/{0}:{1}" -f $site.Host, $site.AbsolutePath.TrimEnd('/'))
if ($Library) {
    $drives = (Invoke-MgGraphRequest -Method GET -Uri "$graph/sites/$($siteObj.id)/drives").value
    $drive = $drives | Where-Object { $_.name -eq $Library } | Select-Object -First 1
    if (-not $drive) { throw "Library '$Library' not found. Available libraries: $(($drives | ForEach-Object name) -join ', ')" }
}
else { $drive = Invoke-MgGraphRequest -Method GET -Uri "$graph/sites/$($siteObj.id)/drive" }
Write-Output ("   Site: {0} · Library: {1}" -f $siteObj.displayName, $drive.name)

# ---------- 4. Upload ----------
Step '4. Upload'
$i = 0
foreach ($f in $files) {
    $i++
    $rel = $f.FullName.Substring($Path.Length + 1)
    $target = Get-EncodedPath ("$Folder/$rel")
    Invoke-MgGraphRequest -Method PUT -Uri "$graph/drives/$($drive.id)/root:/${target}:/content" -InputFilePath $f.FullName -ContentType 'application/octet-stream' | Out-Null
    Write-Progress -Activity 'Uploading to SharePoint' -Status $rel -PercentComplete ($i * 100 / $files.Count)
}
Write-Progress -Activity 'Uploading to SharePoint' -Completed
Write-Output "   Uploaded ${i} files."

$pubItem = Invoke-MgGraphRequest -Method GET -Uri ("$graph/drives/$($drive.id)/root:/{0}" -f (Get-EncodedPath "$Folder/Published"))
$pubUrl = $pubItem.webUrl

Step 'Done: three manual steps'
Write-Output "   Published/ folder URL: $pubUrl"
Write-Output '   1) Permissions: Published folder → Manage access → Stop inheriting permissions → only approvers can edit; everyone else has read-only access.'
Write-Output '   2) Copilot Studio: new agent → five instruction lines → remove "Search all websites" from knowledge → Add knowledge → SharePoint → register only the URL above.'
Write-Output '   3) Test: ask the ten questions in questions.md in the preview pane. Publish to Teams only after all pass, including the six that require the agent to admit it does not know.'
