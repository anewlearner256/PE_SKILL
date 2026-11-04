<#
.SYNOPSIS
  Reports the encoding class of source files and which editing route is safe.
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File enc_detect.ps1 Plugin.cpp MainDlg.h
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File enc_detect.ps1 -Dir .\Plugins\Foo
#>
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)][string[]]$Path,
    [string]$Dir,
    [string[]]$Extensions = @('.h', '.hpp', '.c', '.cpp', '.cc', '.cxx', '.inl', '.rc', '.rc2')
)
. (Join-Path $PSScriptRoot 'encoding_lib.ps1')
Set-Utf8Console

$files = @()
if ($Path) { $files += $Path | ForEach-Object { (Resolve-Path -LiteralPath $_).ProviderPath } }
if ($Dir) { $files += Get-ChildItem -LiteralPath $Dir -Recurse -File |
    Where-Object { $Extensions -contains $_.Extension.ToLowerInvariant() -and $_.FullName -notmatch '[\\/]\.(git|vs|codegraph)[\\/]' } |
    ForEach-Object { $_.FullName } }
if (-not $files) { Fail 'Pass file paths or -Dir <folder>.' }

$route = @{
    'utf16'      = 'leave alone (UTF-16, e.g. VS .rc); edit in Visual Studio'
    'utf8-bom'   = 'normal edit tools OK (keep the BOM)'
    'bad-bom'    = 'DAMAGED BOM - restore from git: git checkout HEAD -- <file>'
    'ascii'      = 'normal edit tools OK only for ASCII changes; adding Chinese -> gbk_replace.ps1'
    'utf8-nobom' = 'LATENT BUG: MSVC compiles it as GBK -> run enc_convert.ps1 -To gbk (or utf8bom)'
    'gbk'        = 'GBK: use gbk_read.ps1 / gbk_replace.ps1 / gbk_write.ps1 only'
}

foreach ($f in $files) {
    $b = [System.IO.File]::ReadAllBytes($f)
    $cls = Get-FileEncodingClass $b
    $extra = ''
    if ($cls -eq 'utf8-nobom' -and $f -like '*.rc*' -and (Test-DeclaresUtf8CodePage $b)) {
        '{0,-10} {1}' -f $cls, $f
        '           -> OK: declares #pragma code_page(65001); edit with normal tools'
        continue
    }
    if ($cls -eq 'gbk') {
        $bad = Get-GbkInvalidCount $b
        $fffd = Get-ReplacementCharCount $b
        if ($bad -gt 0 -or $fffd -gt 0) { $extra = " [warning: $bad invalid GBK byte(s), $fffd U+FFFD sequence(s) - already damaged? compare with git]" }
    }
    '{0,-10} {1}{2}' -f $cls, $f, $extra
    '           -> ' + $route[$cls]
}
