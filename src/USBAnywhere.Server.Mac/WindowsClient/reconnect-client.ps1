# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[0-9.]+$')][string]$Server,
    [ValidateSet('low-latency','zero-copy')][string]$ReceiveMode='low-latency',
    [ValidatePattern('^(auto|1-[0-9]{1,2}(,1-[0-9]{1,2})*)$')][string]$BusIDs='auto',
    [ValidateRange(0,1000)][int]$TestIterations=0,
    [string]$TestClientPath='',
    [ValidateRange(0,5000)][int]$TestDelayMilliseconds=0
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'client-discovery.ps1')
$requestedIDs=@(Get-RequestedBusIDs $BusIDs)
$parsed = $null
if (-not [Net.IPAddress]::TryParse($Server,[ref]$parsed) -or $parsed.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { throw 'An IPv4 server address is required' }
$testMode=$TestIterations -gt 0
$clientPath=Join-Path $PSScriptRoot 'usbip.exe'
if ($testMode) {
    if (-not [IO.Path]::IsPathRooted($TestClientPath) -or
        [IO.Path]::GetExtension($TestClientPath) -ne '.exe' -or
        -not (Test-Path -LiteralPath $TestClientPath -PathType Leaf)) {
        throw 'A bounded test requires an absolute path to its fake client executable'
    }
    $clientPath=(Resolve-Path -LiteralPath $TestClientPath).Path
} elseif ($TestClientPath -or $TestDelayMilliseconds -ne 0) {
    throw 'Test client and delay overrides require bounded TestIterations'
}
$mutexName=if($testMode){'Local\USBAnywhereMacReconnectTest-'+[Guid]::NewGuid().ToString('N')}else{'Global\USBAnywhereMacReconnect-'+$Server}
$mutex = [Threading.Mutex]::new($false,$mutexName)
$owned = $false
$log = Join-Path $PSScriptRoot 'reconnect.log'
function Write-State([string]$state) {
    if ((Test-Path $log) -and (Get-Item $log).Length -gt 1048576) {
        if (Test-Path "$log.1") { Remove-Item "$log.1" }
        Move-Item $log "$log.1"
    }
    $line = (Get-Date -Format o) + ' ' + $state
    Add-Content -Encoding UTF8 -Path $log -Value $line
    Write-Output $line
}
function Invoke-Client([string]$arguments) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $clientPath
    $start.WorkingDirectory = $PSScriptRoot
    $start.Arguments = $arguments
    $start.UseShellExecute=$false; $start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
    $process = [Diagnostics.Process]::new(); $process.StartInfo=$start
    try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(8000)) {
            $process.Kill(); [void]$process.WaitForExit(2000)
            throw 'USB/IP client command timed out'
        }
        return @{code=$process.ExitCode;output=$stdout.Result;error=$stderr.Result}
    } finally { $process.Dispose() }
}
try {
    try { $owned=$mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $owned=$true }
    if (-not $owned) { exit 0 }
    $lastStates=@{}
    $automatic=$BusIDs -eq 'auto'
    $devices=$requestedIDs
    $nextScan=[DateTime]::MinValue
    $lastDiscoveryError=$null
    $iteration=0
    while ($true) {
        if($automatic -and [DateTime]::UtcNow -ge $nextScan) {
            try {
                $discovered=Invoke-Client "list -r $Server"
                if($discovered.code -ne 0){throw 'Server unavailable'}
                $devices=@(Get-ExportedBusIDs $discovered.output)
                if($lastDiscoveryError){Write-State 'Server discovery restored'}
                $lastDiscoveryError=$null
            } catch {
                $message='Discovery waiting: '+$_.Exception.Message
                if($message -ne $lastDiscoveryError){Write-State $message; $lastDiscoveryError=$message}
            }
            $nextScan=if($testMode){[DateTime]::MinValue}else{[DateTime]::UtcNow.AddSeconds(5)}
        }
        foreach ($busID in $devices) {
        try {
            $ports=Invoke-Client 'port'
            $connected=$ports.code -eq 0 -and ($ports.output -match ('(?m)^\s*->\s+usbip://' + [Regex]::Escape($Server) + ':3240/' + [Regex]::Escape($busID) + '\s*$'))
            if (-not $connected) {
                $attached=Invoke-Client "attach -r $Server -b $busID --receive-mode=$ReceiveMode --once"
                $connected=$attached.code -eq 0
            }
            $state=if($connected){"connected ($ReceiveMode)"}else{'waiting for server/device'}
        } catch { $state='waiting: ' + $_.Exception.Message }
        if ($state -ne $lastStates[$busID]) { Write-State "$busID $state"; $lastStates[$busID]=$state }
        }
        $iteration++
        if ($testMode -and $iteration -ge $TestIterations) { break }
        if ($testMode) {
            if ($TestDelayMilliseconds -gt 0) { Start-Sleep -Milliseconds $TestDelayMilliseconds }
        } else { Start-Sleep -Seconds 2 }
    }
} finally {
    if ($owned) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
