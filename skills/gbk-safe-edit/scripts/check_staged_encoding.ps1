<#
.SYNOPSIS
  git pre-commit check: blocks commits that damage GBK / UTF-8-BOM C/C++ sources.

.DESCRIPTION
  Compares each staged C/C++/rc file with its HEAD version and blocks when:
    - U+FFFD sequences (EF BF BD, shown as mojibake in GBK) increased
    - invalid GBK byte count increased (byte misalignment from a lossy round trip)
    - the UTF-8 BOM was damaged (EF BB 3F ...)
    - the file became BOM-less UTF-8 with non-ASCII text (MSVC compiles it as GBK)
      .rc files declaring #pragma code_page(65001) are exempt
  Bypass once:  git commit --no-verify   or   set PE_SKIP_ENCODING_CHECK=1
#>
param([string]$RepoRoot = '.')
. (Join-Path $PSScriptRoot 'encoding_lib.ps1')
Set-Utf8Console

if ($env:PE_SKIP_ENCODING_CHECK -eq '1') { exit 0 }

$Extensions = @('.h', '.hpp', '.c', '.cpp', '.cc', '.cxx', '.inl', '.rc', '.rc2')
$MaxBytes = 8MB

# Runs git and returns stdout as raw bytes (PowerShell pipelines would decode and mangle them).
function Invoke-GitBytes([string[]]$GitArgs) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    $psi.Arguments = ($GitArgs | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' '
    $psi.WorkingDirectory = (Resolve-Path -LiteralPath $RepoRoot).ProviderPath
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $ms = New-Object System.IO.MemoryStream
    $errTask = $p.StandardError.ReadToEndAsync()
    $p.StandardOutput.BaseStream.CopyTo($ms)
    $p.WaitForExit()
    [void]$errTask.Result
    if ($p.ExitCode -ne 0) { return $null }
    return ,$ms.ToArray()
}

$hasHead = $null -ne (Invoke-GitBytes @('rev-parse', '--verify', '-q', 'HEAD'))
$listBytes = Invoke-GitBytes @('-c', 'core.quotepath=off', 'diff', '--cached', '--name-only', '-z', '--diff-filter=ACMR')
if (-not $listBytes) { exit 0 }
$paths = $script:Utf8Strict.GetString($listBytes).Split([char]0, [StringSplitOptions]::RemoveEmptyEntries) |
    Where-Object { $Extensions -contains [System.IO.Path]::GetExtension($_).ToLowerInvariant() }

$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

foreach ($path in $paths) {
    $new = Invoke-GitBytes @('cat-file', 'blob', ":$path")
    if ($null -eq $new -or $new.Length -gt $MaxBytes) { continue }
    $old = $null
    if ($hasHead) { $old = Invoke-GitBytes @('cat-file', 'blob', "HEAD:$path") }

    $newCls = Get-FileEncodingClass $new
    if ($newCls -eq 'utf16') { continue }
    $oldCls = if ($null -ne $old) { Get-FileEncodingClass $old } else { '(new file)' }

    if ($newCls -eq 'bad-bom') {
        $errors.Add("$path : UTF-8 BOM damaged (EF BB ..) - typical of a GBK read/write round trip on a UTF-8 file.")
        continue
    }

    $newFffd = Get-ReplacementCharCount $new
    $oldFffd = if ($null -ne $old) { Get-ReplacementCharCount $old } else { 0 }
    if ($newFffd -gt $oldFffd) {
        $errors.Add("$path : U+FFFD replacement characters $oldFffd -> $newFffd. Chinese text was destroyed by an editor that read GBK as UTF-8.")
    }

    if ($newCls -eq 'utf8-nobom' -and -not ([System.IO.Path]::GetExtension($path) -like '.rc*' -and (Test-DeclaresUtf8CodePage $new))) {
        if ($oldCls -eq 'utf8-nobom') {
            $warnings.Add("$path : BOM-less UTF-8 (pre-existing). MSVC compiles it as GBK; consider enc_convert.ps1 -To gbk.")
        } else {
            $errors.Add("$path : $oldCls -> BOM-less UTF-8. MSVC will compile it as GBK (C2065/C2143/C4819). Restore it, or convert: enc_convert.ps1 -To gbk / -To utf8bom.")
        }
    }

    if ($newCls -eq 'gbk') {
        $newBad = Get-GbkInvalidCount $new
        $oldBad = if ($oldCls -eq 'gbk') { Get-GbkInvalidCount $old } else { 0 }
        if ($newBad -gt $oldBad) {
            $errors.Add("$path : invalid GBK bytes $oldBad -> $newBad. Bytes are misaligned or mixed encodings were pasted in.")
        }
    }

    if ($oldCls -eq 'utf8-bom' -and $newCls -ne 'utf8-bom' -and $newCls -ne 'utf8-nobom') {
        $warnings.Add("$path : was UTF-8 with BOM, now $newCls. Intended?")
    }
}

foreach ($w in $warnings) { [Console]::Error.WriteLine("encoding check WARNING: $w") }
if ($errors.Count -gt 0) {
    foreach ($e in $errors) { [Console]::Error.WriteLine("encoding check BLOCKED: $e") }
    [Console]::Error.WriteLine('')
    [Console]::Error.WriteLine('Fix: git checkout HEAD -- <file>, then redo the edit with the gbk-safe-edit scripts.')
    [Console]::Error.WriteLine('Bypass once (only if intended): git commit --no-verify')
    exit 1
}
exit 0
