# Shared helpers for GBK-safe editing. Dot-source this file.
# Keep this file ASCII-only: Windows PowerShell 5.1 reads BOM-less .ps1 files
# in the ANSI code page, so any non-ASCII literal here would be misread.

$ErrorActionPreference = 'Stop'

# Prints a one-line error (no PowerShell stack dump) and exits 1.
function Fail([string]$Message) {
    [Console]::Error.WriteLine('ERROR: ' + $Message)
    exit 1
}

# Strict GBK (code page 936): throw instead of silently substituting '?' / U+FFFD.
$script:GbkStrict = [System.Text.Encoding]::GetEncoding(936,
    (New-Object System.Text.EncoderExceptionFallback),
    (New-Object System.Text.DecoderExceptionFallback))
# Lenient GBK for display only.
$script:GbkLoose = [System.Text.Encoding]::GetEncoding(936)
$script:Utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
# Latin-1 maps every byte to exactly one char and back: lossless byte<->string.
$script:Latin1 = [System.Text.Encoding]::GetEncoding(28591)

function Test-Utf8Valid([byte[]]$Bytes, [int]$Start = 0) {
    try { [void]$script:Utf8Strict.GetString($Bytes, $Start, $Bytes.Length - $Start); return $true }
    catch { return $false }
}

function Test-HasNonAscii([byte[]]$Bytes) {
    return [regex]::IsMatch($script:Latin1.GetString($Bytes), '[\x80-\xFF]')
}

# Byte-scanning loops are compiled once per process; pure PowerShell loops
# take seconds per file.
if (-not ('PeToolkit.GbkScan' -as [type])) {
    Add-Type -TypeDefinition @"
namespace PeToolkit {
public static class GbkScan {
    static bool IsTrail(byte t) { return t >= 0x40 && t <= 0xFE && t != 0x7F; }
    public static int InvalidCount(byte[] b) {
        int bad = 0, i = 0, n = b.Length;
        while (i < n) {
            byte c = b[i];
            if (c < 0x80) { i++; continue; }
            if (c >= 0x81 && c <= 0xFE && i + 1 < n && IsTrail(b[i + 1])) { i += 2; continue; }
            bad++; i++;
        }
        return bad;
    }
    // 0x0A is never a GBK trail byte, so line starts are safe sync points.
    public static bool IsBoundary(byte[] b, int pos) {
        int i = pos;
        while (i > 0 && b[i - 1] != 0x0A) i--;
        while (i < pos) {
            byte c = b[i];
            if (c >= 0x81 && c <= 0xFE && i + 1 < b.Length && IsTrail(b[i + 1])) i += 2; else i++;
        }
        return i == pos;
    }
    public static int LineAt(byte[] b, int pos) {
        int line = 1;
        for (int i = 0; i < pos; i++) if (b[i] == 0x0A) line++;
        return line;
    }
    public static bool LfDominant(byte[] b) {
        int crlf = 0, lf = 0;
        for (int i = 0; i < b.Length; i++)
            if (b[i] == 0x0A) { if (i > 0 && b[i - 1] == 0x0D) crlf++; else lf++; }
        return lf > crlf;
    }
}
}
"@
}

# Counts byte positions that are not part of a well-formed GBK character.
function Get-GbkInvalidCount([byte[]]$Bytes) { return [PeToolkit.GbkScan]::InvalidCount($Bytes) }

# Number of U+FFFD replacement characters as UTF-8 bytes (EF BF BD).
# In a GBK file the same bytes render as the infamous mojibake "kun jin kao".
function Get-ReplacementCharCount([byte[]]$Bytes) {
    $s = $script:Latin1.GetString($Bytes)
    $needle = [string][char]0xEF + [char]0xBF + [char]0xBD
    $count = 0; $idx = 0
    while (($idx = $s.IndexOf($needle, $idx, [StringComparison]::Ordinal)) -ge 0) { $count++; $idx += 3 }
    return $count
}

# Returns one of:
#   utf16      UTF-16 BOM (typical for Visual Studio .rc files) - do not touch with GBK tools
#   utf8-bom   UTF-8 with BOM - ordinary editors are fine
#   bad-bom    starts with EF BB but not EF BB BF - a UTF-8 BOM damaged by a GBK round trip
#   ascii      pure ASCII - ordinary editors are fine AS LONG AS no non-ASCII text is added
#   utf8-nobom valid UTF-8 with non-ASCII bytes and no BOM - MSVC compiles it as GBK: latent bug
#   gbk        everything else - only use the GBK scripts
function Get-FileEncodingClass([byte[]]$Bytes) {
    $n = $Bytes.Length
    if ($n -ge 2 -and (($Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) -or ($Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF))) { return 'utf16' }
    if ($n -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) { return 'utf8-bom' }
    if ($n -ge 2 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB) { return 'bad-bom' }
    if (-not (Test-HasNonAscii $Bytes)) { return 'ascii' }
    if (Test-Utf8Valid $Bytes) { return 'utf8-nobom' }
    return 'gbk'
}

function Get-DominantEol([byte[]]$Bytes) {
    if ([PeToolkit.GbkScan]::LfDominant($Bytes)) { return "`n" }
    return "`r`n"
}

# Converts text to the file's line-ending convention.
function Convert-Eol([string]$Text, [string]$Eol) {
    $t = $Text.Replace("`r`n", "`n")
    if ($Eol -eq "`r`n") { $t = $t.Replace("`n", "`r`n") }
    return $t
}

# Encodes text as GBK; throws with the offending character if it is not representable.
function ConvertTo-GbkBytes([string]$Text) {
    try { return ,$script:GbkStrict.GetBytes($Text) }
    catch {
        foreach ($ch in $Text.ToCharArray()) {
            try { [void]$script:GbkStrict.GetBytes([string]$ch) }
            catch { Fail ("Character U+{0:X4} cannot be encoded as GBK (emoji and rare symbols are not in GBK)." -f [int]$ch) }
        }
        throw
    }
}

# True if byte offset $Pos starts a character (is not the trail byte of a GBK pair).
function Test-GbkCharBoundary([byte[]]$Bytes, [int]$Pos) { return [PeToolkit.GbkScan]::IsBoundary($Bytes, $Pos) }

function Get-LineNumberAt([byte[]]$Bytes, [int]$Pos) { return [PeToolkit.GbkScan]::LineAt($Bytes, $Pos) }

# .rc files may legitimately be BOM-less UTF-8 when they declare it.
function Test-DeclaresUtf8CodePage([byte[]]$Bytes) {
    return $script:Latin1.GetString($Bytes).Contains('#pragma code_page(65001)')
}

# Writes UTF-8 to stdout so the calling agent can read Chinese text.
function Set-Utf8Console {
    try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch {}
    $global:OutputEncoding = New-Object System.Text.UTF8Encoding($false)
}

function Read-Utf8TextFile([string]$Path) {
    $b = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path).ProviderPath)
    $start = 0
    if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) { $start = 3 }
    return $script:Utf8Strict.GetString($b, $start, $b.Length - $start)
}
