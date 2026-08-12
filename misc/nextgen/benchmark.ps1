param(
    [Parameter(Mandatory = $true)]
    [string] $UpxPath,

    [Parameter(Mandatory = $true)]
    [string[]] $InputFiles,

    [ValidateRange(1, 1000)]
    [int] $Iterations = 10,

    [string] $OutputPath = (Join-Path $PWD 'upx-nextgen-benchmark.csv'),

    [ValidateRange(100, 600000)]
    [int] $TimeoutMilliseconds = 60000
)

$ErrorActionPreference = 'Stop'

function Get-Median([double[]] $Values) {
    $ordered = @($Values | Sort-Object)
    if ($ordered.Count -eq 0) {
        return 0.0
    }
    $middle = [int][Math]::Floor($ordered.Count / 2)
    if (($ordered.Count % 2) -eq 1) {
        return [double]$ordered[$middle]
    }
    return ([double]$ordered[$middle - 1] + [double]$ordered[$middle]) / 2.0
}

function Invoke-Upx([string[]] $Arguments) {
    & $UpxPath @Arguments | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "UPX failed with exit code ${LASTEXITCODE}: $($Arguments -join ' ')"
    }
}

function Measure-Executable([string] $Path, [string] $ScratchDirectory) {
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Path
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $watch = [Diagnostics.Stopwatch]::StartNew()
    if (-not $process.Start()) {
        throw "benchmark target could not be started: $Path"
    }

    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $peakWorkingSetBytes = 0L
    $peakPrivateMemoryBytes = 0L
    while ($true) {
        try {
            $process.Refresh()
            $peakWorkingSetBytes = [Math]::Max($peakWorkingSetBytes, $process.WorkingSet64)
            $peakPrivateMemoryBytes = [Math]::Max($peakPrivateMemoryBytes, $process.PrivateMemorySize64)
        }
        catch [InvalidOperationException] {
            # Very short-lived processes can exit between Refresh() and a counter read.
        }
        if ($process.WaitForExit(1)) {
            break
        }
        if ($watch.ElapsedMilliseconds -ge $TimeoutMilliseconds) {
            $process.Kill()
            $process.WaitForExit()
            throw "benchmark timed out after $TimeoutMilliseconds ms: $Path"
        }
    }
    $process.WaitForExit()
    $watch.Stop()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) {
        throw "benchmark target exited with $($process.ExitCode): $Path`n$stderr"
    }
    [pscustomobject]@{
        WallMilliseconds = $watch.Elapsed.TotalMilliseconds
        PeakWorkingSetBytes = $peakWorkingSetBytes
        PeakPrivateMemoryBytes = $peakPrivateMemoryBytes
        CpuMilliseconds = $process.TotalProcessorTime.TotalMilliseconds
    }
}

$resolvedUpx = (Resolve-Path -LiteralPath $UpxPath).Path
$UpxPath = $resolvedUpx
$rows = [Collections.Generic.List[object]]::new()
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('upx-nextgen-benchmark-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null

try {
    foreach ($input in $InputFiles) {
        $source = (Resolve-Path -LiteralPath $input).Path
        $name = [IO.Path]::GetFileNameWithoutExtension($source)
        $extension = [IO.Path]::GetExtension($source)
        $traditional = Join-Path $scratch ($name + '-traditional' + $extension)
        $nextgen = Join-Path $scratch ($name + '-nextgen' + $extension)

        Invoke-Upx @('-7', '--no-progress', '-q', '-o', $traditional, $source)
        Invoke-Upx @('--fast-start', '--no-progress', '-q', '-o', $nextgen, $source)

        $profiles = @(
            [pscustomobject]@{ Name = 'Original'; Path = $source },
            [pscustomobject]@{ Name = 'TraditionalUPX'; Path = $traditional },
            [pscustomobject]@{ Name = 'NextGenFastStart'; Path = $nextgen }
        )
        $measurements = @{}
        foreach ($profile in $profiles) {
            $samples = [Collections.Generic.List[object]]::new()
            for ($iteration = 1; $iteration -le $Iterations; ++$iteration) {
                $samples.Add((Measure-Executable $profile.Path $scratch))
            }
            $measurements[$profile.Name] = $samples
        }

        $baselineMilliseconds = Get-Median @($measurements['Original'] | ForEach-Object WallMilliseconds)
        foreach ($profile in $profiles) {
            $samples = $measurements[$profile.Name]
            $wallMilliseconds = Get-Median @($samples | ForEach-Object WallMilliseconds)
            $rows.Add([pscustomobject]@{
                Input = $source
                Profile = $profile.Name
                Iterations = $Iterations
                FileBytes = (Get-Item -LiteralPath $profile.Path).Length
                StartupMillisecondsMedian = [Math]::Round($wallMilliseconds, 3)
                StartupOverheadMilliseconds = [Math]::Round($wallMilliseconds - $baselineMilliseconds, 3)
                PeakWorkingSetBytesMedian = [Math]::Round((Get-Median @($samples | ForEach-Object PeakWorkingSetBytes)))
                PeakPrivateMemoryBytesMedian = [Math]::Round((Get-Median @($samples | ForEach-Object PeakPrivateMemoryBytes)))
                CpuMillisecondsMedian = [Math]::Round((Get-Median @($samples | ForEach-Object CpuMilliseconds)), 3)
            })
        }
    }

    $rows | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8
    $rows | Format-Table -AutoSize
    Write-Host "Benchmark CSV: $OutputPath"
}
finally {
    if (Test-Path -LiteralPath $scratch) {
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
}
