<#
.SYNOPSIS
  Exact-text replacement inside a GBK (or ASCII) file, done at byte level.

.DESCRIPTION
  Old/New text are encoded to GBK and swapped as raw bytes. The file is never
  decoded and re-encoded as a whole, so bytes outside the match - including any
  pre-existing damaged bytes - stay exactly as they were.

  - Line endings in Old/New are converted to the file's own convention (CRLF/LF).
  - By default Old must match exactly once; use -All to replace every match.
  - Matches starting in the middle of a GBK double-byte character are ignored.
  - -OldFile/-NewFile read UTF-8 text files (use them for multi-line or Chinese
    text); exactly one trailing newline is stripped from each.
  - -Delete removes the Old text (powershell -File drops empty "" arguments,
    so -New "" does not work).

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File gbk_replace.ps1 Plugin.cpp -OldFile old.txt -NewFile new.txt
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File gbk_replace.ps1 Plugin.cpp -Old "bAddToMenu, false" -New "bAddToMenu, true" -DryRun
#>
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Path,
    [string]$Old,
    [string]$New,
    [string]$OldFile,
    [string]$NewFile,
    [switch]$Delete,
    [switch]$All,
    [switch]$DryRun
)
. (Join-Path $PSScriptRoot 'encoding_lib.ps1')
Set-Utf8Console

function Strip-OneTrailingNewline([string]$s) {
    if ($s.EndsWith("`r`n")) { return $s.Substring(0, $s.Length - 2) }
    if ($s.EndsWith("`n")) { return $s.Substring(0, $s.Length - 1) }
    return $s
}

if ($OldFile) { $Old = Strip-OneTrailingNewline (Read-Utf8TextFile $OldFile) }
if ($NewFile) { $New = Strip-OneTrailingNewline (Read-Utf8TextFile $NewFile) }
if ($Delete) { $New = '' }
if ([string]::IsNullOrEmpty($Old)) { Fail 'Old text is empty. Pass -Old or -OldFile.' }
if (-not ($PSBoundParameters.ContainsKey('New') -or $NewFile -or $Delete)) { Fail 'New text missing. Pass -New, -NewFile, or -Delete to remove the Old text.' }

$full = (Resolve-Path -LiteralPath $Path).ProviderPath
$bytes = [System.IO.File]::ReadAllBytes($full)
$cls = Get-FileEncodingClass $bytes
switch ($cls) {
    'utf16'      { Fail "$Path is UTF-16. Do not edit it with GBK tools." }
    'utf8-bom'   { Fail "$Path is UTF-8 with BOM. Use your normal edit tool instead." }
    'bad-bom'    { Fail "$Path has a damaged UTF-8 BOM (EF BB ..). Restore it from git first." }
    'utf8-nobom' { Fail "$Path is BOM-less UTF-8, which MSVC compiles as GBK. Convert it first: enc_convert.ps1 -Path <file> -To gbk" }
}

$eol = Get-DominantEol $bytes
$oldBytes = ConvertTo-GbkBytes (Convert-Eol $Old $eol)
$newBytes = ConvertTo-GbkBytes (Convert-Eol $New $eol)

# Latin-1 string view: one char per byte, so string search == byte search.
$hay = $script:Latin1.GetString($bytes)
$needle = $script:Latin1.GetString($oldBytes)

$hits = New-Object System.Collections.Generic.List[int]
$skipped = 0
$idx = 0
while (($idx = $hay.IndexOf($needle, $idx, [StringComparison]::Ordinal)) -ge 0) {
    if (Test-GbkCharBoundary $bytes $idx) { $hits.Add($idx); $idx += $oldBytes.Length }
    else { $skipped++; $idx++ }
}

$lines = $hits | ForEach-Object { Get-LineNumberAt $bytes $_ }
if ($hits.Count -eq 0) {
    $hint = ''
    if ($skipped) { $hint = " ($skipped byte-level hit(s) started inside a GBK character and were ignored)" }
    Fail "Old text not found in $Path$hint. Re-read the file with gbk_read.ps1 and copy the text exactly (indentation included)."
}
if ($hits.Count -gt 1 -and -not $All) {
    Fail "Old text matches $($hits.Count) times (lines $($lines -join ', ')). Add surrounding lines to make it unique, or pass -All."
}

# Rebuild: untouched prefix + new bytes + untouched suffix, for each match.
$out = New-Object System.IO.MemoryStream
$pos = 0
foreach ($m in $hits) {
    $out.Write($bytes, $pos, $m - $pos)
    $out.Write($newBytes, 0, $newBytes.Length)
    $pos = $m + $oldBytes.Length
}
$out.Write($bytes, $pos, $bytes.Length - $pos)
$result = $out.ToArray()

$verb = if ($DryRun) { 'Would replace' } else { 'Replaced' }
"$verb $($hits.Count) occurrence(s) in $Path at line(s) $($lines -join ', ') [$cls, EOL=$(if ($eol -eq "`r`n") {'CRLF'} else {'LF'})]; size $($bytes.Length) -> $($result.Length) bytes."
if (-not $DryRun) {
    [System.IO.File]::WriteAllBytes($full, $result)
    'All bytes outside the replaced range are unchanged. Verify with: git diff -- "' + $Path + '"'
}
