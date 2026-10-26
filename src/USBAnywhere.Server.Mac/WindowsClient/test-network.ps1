# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
param([Parameter(Mandatory=$true)][string]$Server, [int]$BlockedSeconds = 30)
# Blocks only USB/IP to this server; SSH and other traffic remain reachable.
$ErrorActionPreference='Stop'
$client = Join-Path $PSScriptRoot 'usbip.exe'
$rulePrefix = 'USBAnywhere-Reliability-' + [Guid]::NewGuid().ToString('N')
$output = & $client attach -r $Server -b 1-1 --receive-mode=low-latency -t
if ($LASTEXITCODE -ne 0) { throw 'Initial network-test attach failed' }
$port = [int](@($output | Where-Object { $_ -match '^\s*\d+\s*$' }) | Select-Object -Last 1)
Start-Sleep -Seconds 1
$before = (& (Join-Path $PSScriptRoot 'verify-input.ps1') -Seconds 2) | ConvertFrom-Json
if ($before.samples -eq 0 -or $before.readFailures -ne 0) { throw 'No input before network interruption' }
try {
    New-NetFirewallRule -Name "$rulePrefix-out" -DisplayName "$rulePrefix-out" -Direction Outbound -Action Block -Protocol TCP -RemoteAddress $Server -RemotePort 3240 | Out-Null
    New-NetFirewallRule -Name "$rulePrefix-in" -DisplayName "$rulePrefix-in" -Direction Inbound -Action Block -Protocol TCP -RemoteAddress $Server -RemotePort 3240 | Out-Null
    $probe = [Net.Sockets.TcpClient]::new()
    try {
        $attempt = $probe.ConnectAsync($Server,3240)
        if ($attempt.Wait(2000) -and $probe.Connected) {
            throw 'The artificial network block is ineffective. Check the active firewall profile; this run cannot validate recovery.'
        }
    } finally { $probe.Dispose() }
    "Blocking only USB/IP traffic for $BlockedSeconds seconds"
    Start-Sleep -Seconds $BlockedSeconds
} finally {
    Get-NetFirewallRule -Name "$rulePrefix-*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    'Temporary USB/IP firewall rules removed'
}
$clock = [Diagnostics.Stopwatch]::StartNew()
while ($clock.Elapsed.TotalSeconds -lt 65) {
    try {
        $connections = @(Get-NetTCPConnection -RemoteAddress $Server -RemotePort 3240 -State Established -ErrorAction SilentlyContinue)
        if ($connections.Count -eq 0) { Start-Sleep -Seconds 2; continue }
        $state = (& (Join-Path $PSScriptRoot 'verify-input.ps1') -Seconds 1) | ConvertFrom-Json
        if ($state.samples -gt 0 -and $state.readFailures -eq 0) {
            "PASS: Windows input recovered automatically after network interruption ($([Math]::Round($clock.Elapsed.TotalSeconds,1)) seconds after unblock)"
            & $client port
            exit 0
        }
    } catch { }
    Start-Sleep -Seconds 2
}
throw "Windows input did not recover automatically within 65 seconds. Test port: $port"
