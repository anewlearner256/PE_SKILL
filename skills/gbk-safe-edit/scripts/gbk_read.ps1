<#
.SYNOPSIS
  Prints a GBK file as UTF-8 with line numbers (like `cat -n`).
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File gbk_read.ps1 Plugin.cpp -Offset 120 -Limit 60
#>
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Path,
    [int]$Offset = 1,
    [int]$Limit = 0
)
. (Join-Path $PSScriptRoot 'encoding_lib.ps1')
Set-Utf8Console

$full = (Resolve-Path -LiteralPath $Path).ProviderPath
$b = [System.IO.File]::ReadAllBytes($full)
$cls = Get-FileEncodingClass $b
if ($cls -eq 'utf16') { Fail "$Path is UTF-16; this script only reads GBK/UTF-8 files." }

$text = if ($cls -eq 'utf8-bom') { $script:Utf8Strict.GetString($b, 3, $b.Length - 3) }
        elseif ($cls -eq 'utf8-nobom') { $script:Utf8Strict.GetString($b) }
        else { $script:GbkLoose.GetString($b) }

$lines = $text.Replace("`r`n", "`n").Split("`n")
if ($lines.Length -gt 1 -and $lines[-1] -eq '') { $lines = $lines[0..($lines.Length - 2)] }
$first = [Math]::Max(1, $Offset)
$last = if ($Limit -gt 0) { [Math]::Min($lines.Length, $first + $Limit - 1) } else { $lines.Length }

"[$cls, $($lines.Length) lines]"
for ($i = $first; $i -le $last; $i++) { '{0,6}  {1}' -f $i, $lines[$i - 1] }
