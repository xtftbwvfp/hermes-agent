param(
    [switch]$Rebase,
    [switch]$SkipChecks,
    [switch]$AllowDirty
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args
    )

    & git @Args
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Args -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    Write-Host ""
    Write-Host "==> $Label" -ForegroundColor Cyan
    & $Action
}

Invoke-Step "Checking repository state" {
    $gitDir = git rev-parse --git-dir 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $gitDir) {
        throw "Current directory is not a git repository: $repoRoot"
    }

    $branch = (git branch --show-current).Trim()
    if (-not $branch) {
        throw "Could not determine current branch."
    }
    if ($branch -ne "windows-native") {
        throw "Current branch is '$branch'. Switch to 'windows-native' before syncing."
    }

    $status = git status --porcelain
    if (-not $AllowDirty -and $status) {
        throw "Working tree is dirty. Commit or stash changes first, or rerun with -AllowDirty."
    }
}

Invoke-Step "Fetching upstream" {
    Invoke-Git -Args @("fetch", "upstream", "main", "--tags")
}

if ($Rebase) {
    Invoke-Step "Rebasing windows-native onto upstream/main" {
        Invoke-Git -Args @("rebase", "upstream/main")
    }
}
else {
    Invoke-Step "Merging upstream/main into windows-native" {
        Invoke-Git -Args @("merge", "--no-edit", "upstream/main")
    }
}

if (-not $SkipChecks) {
    Invoke-Step "Running Windows smoke checks" {
        $commands = @(
            @("python", "-m", "hermes_cli.main", "--profile", "winfix", "doctor"),
            @("python", "-m", "hermes_cli.main", "--profile", "winfix", "profile", "list"),
            @("python", "-m", "hermes_cli.main", "--profile", "winfix", "gateway", "status"),
            @("python", "-m", "hermes_cli.main", "--profile", "winfix", "chat", "-q", "请只回复 ok")
        )

        foreach ($command in $commands) {
            Write-Host ""
            Write-Host ('$ ' + ($command -join ' ')) -ForegroundColor DarkGray
            & $command[0] $command[1..($command.Length - 1)]
            if ($LASTEXITCODE -ne 0) {
                throw "Smoke check failed: $($command -join ' ')"
            }
        }
    }
}

Write-Host ""
Write-Host "windows-native is now synced with upstream/main." -ForegroundColor Green
