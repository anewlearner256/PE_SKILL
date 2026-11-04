<#
.SYNOPSIS
  Installs the pe-dev-toolkit skills for Codex (and optionally Claude Code),
  and the encoding pre-commit hook into the given git repositories.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Repo D:\work\pe-sdk
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Repo D:\work\pe-sdk,D:\work\other -ClaudeCode
#>
param(
    [string[]]$Repo,
    [switch]$ClaudeCode,
    [string]$SkillsDir = (Join-Path $HOME '.agents\skills')
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

function Install-Skills([string]$Dest) {
    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $root 'skills') -Directory | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $Dest -Recurse -Force
        "  skill $($_.Name) -> $(Join-Path $Dest $_.Name)"
    }
}

'Installing skills (Codex: ~/.agents/skills):'
Install-Skills $SkillsDir
if ($ClaudeCode) {
    'Installing skills (Claude Code: ~/.claude/skills):'
    Install-Skills (Join-Path $HOME '.claude\skills')
}

$check = (Join-Path $SkillsDir 'gbk-safe-edit\scripts\check_staged_encoding.ps1').Replace('\', '/')
$template = [System.IO.File]::ReadAllText((Join-Path $root 'git-hooks\pre-commit')).Replace("`r`n", "`n")
$hook = $template.Replace('__CHECK_SCRIPT__', $check)

foreach ($r in $Repo) {
    $repoPath = (Resolve-Path -LiteralPath $r).ProviderPath
    $hooksRel = (& git -C $repoPath rev-parse --git-path hooks)
    if ($LASTEXITCODE -ne 0) { Write-Warning "$r is not a git repository; skipped."; continue }
    $hooksDir = if ([System.IO.Path]::IsPathRooted($hooksRel)) { $hooksRel } else { Join-Path $repoPath $hooksRel }
    New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null
    $target = Join-Path $hooksDir 'pre-commit'
    if ((Test-Path -LiteralPath $target) -and -not ((Get-Content -LiteralPath $target -Raw) -match 'pe-dev-toolkit')) {
        Write-Warning "$target already exists and is not ours; left untouched. Add this line to it manually:"
        "    powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$check`" -RepoRoot `"`$(git rev-parse --show-toplevel)`" || exit 1"
        continue
    }
    [System.IO.File]::WriteAllText($target, $hook, (New-Object System.Text.UTF8Encoding($false)))
    "  pre-commit hook -> $target"
}
if (-not $Repo) { 'No -Repo given: pre-commit hook not installed. Re-run with -Repo <path-to-pe-sdk>.' }
'Done. Restart Codex so it picks up the new skills.'
