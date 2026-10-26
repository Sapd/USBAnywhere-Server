# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
param([Parameter(Mandatory=$true)][string]$Server)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$client=Join-Path $PSScriptRoot 'usbip.exe'
$before=(& (Join-Path $PSScriptRoot 'verify-dual-input.ps1') -Seconds 1) | ConvertFrom-Json
$task=Get-ScheduledTask -TaskName 'USBAnywhere Mac Reconnect' -ErrorAction SilentlyContinue
$resume=$task -and $task.State -eq 'Running'
if($resume){Stop-ScheduledTask -TaskName $task.TaskName; Start-Sleep -Milliseconds 300}
try {
    $ports=& $client port
    $currentPort=$null; $detach=@()
    foreach($line in $ports) {
        if($line -match '^Port\s+(\d+):'){$currentPort=[int]$Matches[1]}
        if($line -match ('usbip://'+[Regex]::Escape($Server)+':3240/1-[12]\s*$')){$detach+=$currentPort}
    }
    if($detach.Count -ne 2){throw 'Expected both test devices attached'}
    foreach($port in $detach){& $client detach -p $port | Out-Null; if($LASTEXITCODE -ne 0){throw 'Detach failed'}}
    Start-Sleep -Seconds 1
    # Force opposite enumeration order, then force the original order.
    foreach($order in @(@('1-1','1-2'),@('1-2','1-1'))) {
        $attached=@()
        foreach($busID in $order) {
            $output=& $client attach -r $Server -b $busID --receive-mode=low-latency --once -t
            if($LASTEXITCODE -ne 0){throw "Attach failed for $busID"}
            $attached += [int](@($output | Where-Object {$_ -match '^\s*\d+\s*$'}) | Select-Object -Last 1)
        }
        Start-Sleep -Seconds 2
        $after=(& (Join-Path $PSScriptRoot 'verify-dual-input.ps1') -Seconds 1) | ConvertFrom-Json
        foreach($product in @('0201','0200')) {
            $a=@($before.directInput | Where-Object {$_.product -eq $product})
            $b=@($after.directInput | Where-Object {$_.product -eq $product})
            if($a.Count -ne 1 -or $b.Count -ne 1 -or $a[0].instanceGuid -ne $b[0].instanceGuid){throw "DirectInput identity changed for $product"}
        }
        if(@(Compare-Object ($before.usbInstanceIds | Sort-Object) ($after.usbInstanceIds | Sort-Object)).Count -ne 0){throw 'USB instance identities changed'}
        "PASS: attach order $($order -join ',') preserves both USB instance IDs and game-controller GUIDs"
        foreach($port in $attached){& $client detach -p $port | Out-Null}
        Start-Sleep -Seconds 1
    }
} finally {if($resume){Start-ScheduledTask -TaskName $task.TaskName}}
