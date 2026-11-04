<#
.SYNOPSIS
  Writes a whole GBK file from UTF-8 text (new files, or full rewrites).

.DESCRIPTION
  Reads -FromFile as UTF-8 (BOM optional), converts line endings to CRLF
  (or LF with -Lf), guarantees a trailing newline (rc.exe fails with RC1004
  without one), and writes GBK bytes. Refuses to overwrite an existing file
  unless -Force; for edits to existing files prefer gbk_replace.ps1.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File gbk_write.ps1 -Path NewDlg.cpp -FromFile draft_utf8.cpp
#>
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$FromFile,
    [switch]$Lf,
    [switch]$Force
)
. (Join-Path $PSScriptRoot 'encoding_lib.ps1')
Set-Utf8Console

if ((Test-Path -LiteralPath $Path) -and -not $Force) {
    Fail "$Path exists. Use gbk_replace.ps1 for edits, or pass -Force to overwrite the whole file."
}
$text = Read-Utf8TextFile $FromFile
$eol = if ($Lf) { "`n" } else { "`r`n" }
$text = Convert-Eol $text $eol
if (-not $text.EndsWith($eol)) { $text += $eol }
$bytes = ConvertTo-GbkBytes $text

$dir = Split-Path -Parent ([System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path)))
if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
$target = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
[System.IO.File]::WriteAllBytes($target, $bytes)
"Wrote $($bytes.Length) bytes (GBK, $(if ($Lf) {'LF'} else {'CRLF'})) to $target"
