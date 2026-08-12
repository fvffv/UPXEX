[CmdletBinding()]
param(
    [string]$Path = '.\upx-stub-timing.bin'
)

$ErrorActionPreference = 'Stop'
$resolved = (Resolve-Path -LiteralPath $Path).Path
$bytes = [IO.File]::ReadAllBytes($resolved)
if ($bytes.Length -ne 64) {
    throw "Unexpected record size $($bytes.Length); expected 64 bytes"
}

$magic = [Text.Encoding]::ASCII.GetString($bytes, 0, 8)
if ($magic -ne 'UPXSTB01') {
    throw "Unexpected timing magic '$magic'"
}

$version = [BitConverter]::ToUInt32($bytes, 8)
$recordSize = [BitConverter]::ToUInt32($bytes, 12)
$frequency = [BitConverter]::ToUInt64($bytes, 16)
if ($version -ne 1 -or $recordSize -ne 64 -or $frequency -eq 0) {
    throw "Invalid timing header: version=$version size=$recordSize frequency=$frequency"
}

$qpc = 0..4 | ForEach-Object { [BitConverter]::ToUInt64($bytes, 24 + 8 * $_) }
for ($index = 1; $index -lt $qpc.Count; ++$index) {
    if ($qpc[$index] -lt $qpc[$index - 1]) {
        throw "QPC timestamps are not monotonic at index $index"
    }
}

function Convert-QpcDeltaToMilliseconds([UInt64]$Start, [UInt64]$End) {
    return [math]::Round((($End - $Start) * 1000.0) / $frequency, 3)
}

[pscustomobject]@{
    File             = $resolved
    FrequencyHz      = $frequency
    DecompressMs     = Convert-QpcDeltaToMilliseconds $qpc[0] $qpc[1]
    FixupsMs         = Convert-QpcDeltaToMilliseconds $qpc[1] $qpc[2]
    RuntimeSetupMs   = Convert-QpcDeltaToMilliseconds $qpc[2] $qpc[3]
    CleanupMs        = Convert-QpcDeltaToMilliseconds $qpc[3] $qpc[4]
    TotalStubMs      = Convert-QpcDeltaToMilliseconds $qpc[0] $qpc[4]
    Qpc0             = $qpc[0]
    Qpc1             = $qpc[1]
    Qpc2             = $qpc[2]
    Qpc3             = $qpc[3]
    Qpc4             = $qpc[4]
} | Format-List
