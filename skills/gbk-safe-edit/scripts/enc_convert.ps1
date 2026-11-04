<#
.SYNOPSIS
  Converts a source file between BOM-less UTF-8 / GBK / UTF-8 with BOM.

.DESCRIPTION
  Main use: fix BOM-less UTF-8 C/C++ files that MSVC silently compiles as GBK
  (symptoms: C2065 / C2143 / C4819 with line numbers that make no sense).
  The source must decode cleanly; nothing is converted if any byte is invalid.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File enc_convert.ps1 -Path mylog.h -To gbk
#>
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][ValidateSet('gbk', 'utf8bom')][string]$To
)
. (Join-Path $PSScriptRoot 'encoding_lib.ps1')
Set-Utf8Console

$full = (Resolve-Path -LiteralPath $Path).ProviderPath
$b = [System.IO.File]::ReadAllBytes($full)
$cls = Get-FileEncodingClass $b

switch ($cls) {
    'utf8-nobom' { $text = $script:Utf8Strict.GetString($b) }
    'utf8-bom'   { $text = $script:Utf8Strict.GetString($b, 3, $b.Length - 3) }
    'gbk'        {
        try { $text = $script:GbkStrict.GetString($b) }
        catch { Fail "$Path contains bytes that are not valid GBK; it may already be damaged. Compare with git before converting." }
    }
    'ascii'      { "$Path is pure ASCII; nothing to convert."; return }
    default      { Fail "$Path is '$cls'; refusing to convert." }
}

if ($To -eq 'gbk') {
    if ($cls -eq 'gbk') { "$Path is already GBK."; return }
    $out = ConvertTo-GbkBytes $text
} else {
    if ($cls -eq 'utf8-bom') { "$Path is already UTF-8 with BOM."; return }
    $body = $script:Utf8Strict.GetBytes($text)
    $out = New-Object byte[] ($body.Length + 3)
    $out[0] = 0xEF; $out[1] = 0xBB; $out[2] = 0xBF
    [Array]::Copy($body, 0, $out, 3, $body.Length)
}
[System.IO.File]::WriteAllBytes($full, $out)
"Converted $Path : $cls -> $To ($($b.Length) -> $($out.Length) bytes)."
