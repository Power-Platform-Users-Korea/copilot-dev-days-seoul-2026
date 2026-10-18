<#
.SYNOPSIS
  Uses gh CLI to publish a vault to a private GitHub repository with approval gates.
.DESCRIPTION
  1. Checks gh authentication. A human signs in in the browser if necessary.
  2. Initializes the vault as a git repository and creates the first commit.
  3. Creates and pushes to a private repository.
  4. Requires PRs, one approval, code owner review, and the 'check' status (vault-check).
  5. Restricts pushes affecting Sources/raw/. Only administrators can bypass this to add raw sources.
  Private repository rules require GitHub Pro for personal accounts or Team or higher
  for organizations. Push rules require an organization. Unavailable rules produce
  warnings; CODEOWNERS review provides fallback protection for raw sources.
  Use -WhatIf to preview actions without changing anything.
.PARAMETER Path
  Vault folder created by New-LlmWiki.ps1.
.PARAMETER Repo
  Repository name: "name" or "organization/name". Defaults to the folder name.
.PARAMETER Approver
  Approver's GitHub login without @, used in CODEOWNERS. Defaults to the signed-in account.
.PARAMETER AllowAdminBypass
  For solo practice only: lets administrators merge without PR approval. Do not use for teams.
.EXAMPLE
  .\scripts\Publish-LlmWikiGitHub.ps1 -Path . -Repo our-llm-wiki -WhatIf
.EXAMPLE
  .\scripts\Publish-LlmWikiGitHub.ps1 -Path . -Repo my-org/our-llm-wiki -Approver hong-gildong
.NOTES
  GM-Social License v2.0 · Copyright (c) 2026 LEE Inhee, Parandurume Inc.
  Source: https://github.com/parandurume-labs/llm-wiki-template
  Retain this notice and the license file when copying or modifying.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$Path,
    [string]$Repo,
    [string]$Approver,
    [switch]$AllowAdminBypass
)

# gh and git also write normal progress messages to stderr. In Windows PowerShell 5.1,
# use Continue and check $LASTEXITCODE directly instead of treating those messages as fatal.
$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Step([string]$msg) { Write-Output ''; Write-Output "== $msg" }
function Show([string]$cmd) { Write-Output "   > $cmd" }
function Invoke-Native([string]$exe, [string[]]$argList) {
    Show ("$exe " + ($argList -join ' '))
    & $exe @argList
    if ($LASTEXITCODE -ne 0) { throw "$exe failed (exit code $LASTEXITCODE)." }
}
function Invoke-GhApiJson([string]$endpoint, [hashtable]$body) {
    $tmp = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllText($tmp, ($body | ConvertTo-Json -Depth 10), $utf8)
        Show "gh api --method POST $endpoint --input <rules JSON>"
        $out = & gh api --method POST $endpoint --input $tmp 2>&1
        return [pscustomobject]@{ Ok = ($LASTEXITCODE -eq 0); Output = ($out -join "`n") }
    }
    finally { Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue }
}

$Path = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
if (-not (Test-Path -LiteralPath (Join-Path $Path 'ontology.md'))) { throw "Not a vault folder (ontology.md missing): $Path" }
if (-not $Repo) { $Repo = Split-Path -Leaf $Path }

# ---------- 1. Tools and sign-in ----------
Step '1. Check gh and git'
foreach ($tool in 'gh', 'git') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        $hint = if ($tool -eq 'gh') { 'winget install --id GitHub.cli' } else { 'winget install --id Git.Git' }
        throw "$tool is missing. Install it with: $hint"
    }
}
& gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Output '   Not signed in to gh. Starting browser sign-in; a human must sign in directly.'
    if ($PSCmdlet.ShouldProcess('GitHub', 'gh auth login --web')) { Invoke-Native gh @('auth', 'login', '--web', '--git-protocol', 'https') }
}
$me = if ($WhatIfPreference) { (& gh api user --jq .login 2>$null) } else { (& gh api user --jq .login) }
if (-not $me) { $me = '<signed-in-account>' }
if (-not $Approver) { $Approver = $me }
Write-Output "   Signed-in account: $me · Approver: @$Approver"

# ---------- 2. CODEOWNERS and first commit ----------
Step '2. Populate CODEOWNERS and create the first commit'
$co = Join-Path $Path '.github\CODEOWNERS'
if (Test-Path -LiteralPath $co) {
    $txt = [IO.File]::ReadAllText($co, $utf8)
    $new = $txt -replace '@your-github-id', "@$Approver"
    if ($new -ne $txt -and $PSCmdlet.ShouldProcess($co, "Set approver to @$Approver")) { [IO.File]::WriteAllText($co, $new, $utf8) }
}
Push-Location -LiteralPath $Path
try {
    if (-not (Test-Path -LiteralPath (Join-Path $Path '.git'))) {
        if ($PSCmdlet.ShouldProcess($Path, 'git init -b main')) { Invoke-Native git @('init', '-b', 'main') }
    }
    if ($PSCmdlet.ShouldProcess($Path, 'git add, git commit')) {
        Invoke-Native git @('add', '-A')
        & git diff --cached --quiet
        if ($LASTEXITCODE -ne 0) { Invoke-Native git @('commit', '-m', 'LLM Wiki skeleton: ontology, templates, rules, and validation script') }
        else { Write-Output '   No new changes to commit.' }
    }

    # ---------- 3. Create repository ----------
    Step "3. Create a private repository and push: $Repo"
    & git remote get-url origin *> $null
    if ($LASTEXITCODE -eq 0) { Write-Output '   origin already exists. Skipping repository creation and pushing only.'; if ($PSCmdlet.ShouldProcess('origin', 'git push')) { Invoke-Native git @('push', '-u', 'origin', 'main') } }
    elseif ($PSCmdlet.ShouldProcess($Repo, 'gh repo create --private --source . --push')) {
        Invoke-Native gh @('repo', 'create', $Repo, '--private', '--source', '.', '--remote', 'origin', '--push')
    }
    $full = if ($WhatIfPreference) { if ($Repo -match '/') { $Repo } else { "$me/$Repo" } } else { (& gh repo view --json nameWithOwner --jq .nameWithOwner) }
    Write-Output "   Repository: https://github.com/$full"

    # ---------- 4. Branch rules ----------
    Step '4. Default branch rules: PR required · one approval · code owner review · required check'
    $bypass = @()
    if ($AllowAdminBypass) { $bypass = @(@{ actor_id = 5; actor_type = 'RepositoryRole'; bypass_mode = 'pull_request' }) }
    $branchRule = @{
        name          = 'Protect main: PR and approval'
        target        = 'branch'
        enforcement   = 'active'
        bypass_actors = $bypass
        conditions    = @{ ref_name = @{ include = @('~DEFAULT_BRANCH'); exclude = @() } }
        rules         = @(
            @{ type = 'deletion' },
            @{ type = 'non_fast_forward' },
            @{ type = 'pull_request'; parameters = @{ required_approving_review_count = 1; dismiss_stale_reviews_on_push = $true; require_code_owner_review = $true; require_last_push_approval = $false; required_review_thread_resolution = $false } },
            @{ type = 'required_status_checks'; parameters = @{ strict_required_status_checks_policy = $false; required_status_checks = @(@{ context = 'check' }) } }
        )
    }
    if ($PSCmdlet.ShouldProcess($full, 'Create branch rules')) {
        $r = Invoke-GhApiJson "repos/$full/rulesets" $branchRule
        if ($r.Ok) { Write-Output '   Branch rules configured.' }
        else {
            Write-Warning "Could not configure branch rules. Private repositories require GitHub Pro for personal accounts or Team or higher for organizations.`n$($r.Output)"
        }
    }

    # ---------- 5. Push rules ----------
    Step '5. Push rules: restrict changes to Sources/raw/ (administrators can bypass)'
    $pushRule = @{
        name          = 'Protect raw sources: no changes to Sources/raw/'
        target        = 'push'
        enforcement   = 'active'
        bypass_actors = @(@{ actor_id = 5; actor_type = 'RepositoryRole'; bypass_mode = 'always' })
        rules         = @(@{ type = 'file_path_restriction'; parameters = @{ restricted_file_paths = @('Sources/raw/**') } })
    }
    if ($PSCmdlet.ShouldProcess($full, 'Create push rules')) {
        $r = Invoke-GhApiJson "repos/$full/rulesets" $pushRule
        if ($r.Ok) { Write-Output '   Push rules configured. Administrators add new raw sources.' }
        else {
            Write-Warning "Could not configure push rules. These require an organization on Team or higher. As a fallback, /Sources/raw/ in CODEOWNERS requires approver review of source changes.`n$($r.Output)"
        }
    }
}
finally { Pop-Location }

Step 'Done'
Write-Output "   Open the repository: gh repo view $full --web"
Write-Output '   Next: open this folder in VS Code and give the agent the "Structure a raw source" prompt from prompts.md.'
Write-Output '   The agent creates drafts on a new branch and opens a PR. The approver clicks Merge.'
