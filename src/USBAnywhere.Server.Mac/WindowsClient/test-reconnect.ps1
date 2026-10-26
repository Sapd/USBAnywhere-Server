# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
param([Parameter(Mandatory=$true)][string]$Server, [int]$Cycles = 20, [int]$InitialPort = 0)
$ErrorActionPreference = 'Stop'
$client = Join-Path $PSScriptRoot 'usbip.exe'
# Stop only this test device's retry worker; do not detach unrelated USB/IP devices.
& $client attach -r $Server -b 1-1 --stop 2>$null | Out-Null
if($InitialPort -eq 0) {
    $currentPort=0
    foreach($line in (& $client port)) {
        if($line -match '^Port\s+(\d+):'){$currentPort=[int]$Matches[1]}
        if($line -match ('usbip://'+[Regex]::Escape($Server)+':3240/1-1\s*$')){$InitialPort=$currentPort;break}
    }
}
if($InitialPort -gt 0) {
    try { & $client detach -p $InitialPort 2>$null | Out-Null }
    catch { if ($_ -notmatch 'not connected') { throw } }
}
Start-Sleep -Seconds 1
$results = @()
for ($cycle = 1; $cycle -le $Cycles; $cycle++) {
    $mode = if ($cycle % 2) { 'low-latency' } else { 'zero-copy' }
    $port = $null
    $clock = [Diagnostics.Stopwatch]::StartNew()
    try {
        $output = & $client attach -r $Server -b 1-1 --once --receive-mode=$mode -t
        if ($LASTEXITCODE -ne 0) { throw "Attach failed on cycle $cycle ($mode)" }
        $portText = @($output | Where-Object { $_ -match '^\s*\d+\s*$' }) | Select-Object -Last 1
        if (-not $portText) { throw "Missing imported port number: $output" }
        $port = [int]$portText
        Start-Sleep -Milliseconds 700
        $state = (& (Join-Path $PSScriptRoot 'verify-input.ps1') -Seconds 1) | ConvertFrom-Json
        if ($state.readFailures -ne 0 -or $state.samples -eq 0) { throw "Input reads failed on cycle $cycle" }
        $results += [ordered]@{cycle=$cycle;mode=$mode;samples=$state.samples;failures=$state.readFailures;seconds=[Math]::Round($clock.Elapsed.TotalSeconds,2)}
        Write-Output "PASS: reconnect cycle $cycle/$Cycles, $mode, $($state.samples) input reads"
    } finally {
        & $client attach -r $Server -b 1-1 --stop 2>$null | Out-Null
        if ($null -ne $port) { & $client detach -p $port | Out-Null }
    }
    Start-Sleep -Milliseconds 500
}
$results | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $PSScriptRoot 'reconnect-results.json')
& (Join-Path $PSScriptRoot 'test-protocol.ps1') -Server $Server
Write-Output "PASS: all $Cycles reconnect cycles completed"
