# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[0-9.]+$')][string]$Server,
    [ValidateSet('low-latency','zero-copy')][string]$ReceiveMode='low-latency',
    [ValidatePattern('^(auto|1-[0-9]{1,2}(,1-[0-9]{1,2})*)$')][string]$BusIDs='auto'
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'client-discovery.ps1')
# Validate the complete request before touching an existing task or installation.
$null=@(Get-RequestedBusIDs $BusIDs)
$parsed=$null
if (-not [Net.IPAddress]::TryParse($Server,[ref]$parsed) -or $parsed.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { throw 'An IPv4 server address is required' }
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
if (-not ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run as administrator' }

function Move-InstallationDirectory([string]$Source,[string]$Destination) {
    # Stop-ScheduledTask can leave a bounded native child holding files briefly.
    for ($attempt=0; $attempt -lt 24; $attempt++) {
        try { [IO.Directory]::Move($Source,$Destination); return }
        catch { if ($attempt -eq 23) { throw }; Start-Sleep -Milliseconds 500 }
    }
}
function Assert-StagedFile([string]$Source,[string]$Staged) {
    if ((Get-Item -LiteralPath $Staged).Length -eq 0 -or
        (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash -ne
        (Get-FileHash -LiteralPath $Staged -Algorithm SHA256).Hash) {
        throw "Staged file is empty or differs from its source: $Source"
    }
    if ([IO.Path]::GetExtension($Staged) -eq '.ps1') {
        $tokens=$null; $parseErrors=$null
        $null=[Management.Automation.Language.Parser]::ParseFile($Staged,[ref]$tokens,[ref]$parseErrors)
        if ($parseErrors.Count -gt 0) { throw "Invalid staged PowerShell script: $Staged" }
    } elseif ([IO.Path]::GetExtension($Staged) -in @('.exe','.dll')) {
        $stream=[IO.File]::OpenRead($Staged)
        try {
            if ($stream.Length -lt 64 -or $stream.ReadByte() -ne 77 -or $stream.ReadByte() -ne 90) {
                throw "Invalid staged Windows executable: $Staged"
            }
        } finally { $stream.Dispose() }
    }
}
$destination=Join-Path $env:ProgramFiles 'USBAnywhereMacClient'
$transaction=[Guid]::NewGuid().ToString('N')
$staging=$destination+'.staging-'+$transaction
$backup=$destination+'.backup-'+$transaction
$failed=$destination+'.failed-'+$transaction
$taskName='USBAnywhere Mac Reconnect'
$oldMoved=$false; $newMoved=$false; $taskTouched=$false; $committed=$false; $rollbackComplete=$false
$existing=$null; $previousXML=$null; $wasRunning=$false
$installationMutex=[Threading.Mutex]::new($false,'Global\USBAnywhereMacReconnectInstall')
$installationOwned=$false
try {
    try { $installationOwned=$installationMutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $installationOwned=$true }
    if (-not $installationOwned) { throw 'Another reconnect installation is already running' }
    New-Item -ItemType Directory -Path $staging | Out-Null
    foreach ($file in @('usbip.exe','usbipw.exe','libusbip.dll','resources.dll','usb.ids','reconnect-client.ps1','client-discovery.ps1')) {
        $source=Join-Path $PSScriptRoot $file
        $staged=Join-Path $staging $file
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing client file: $source" }
        Copy-Item -LiteralPath $source -Destination $staged
        Assert-StagedFile $source $staged
    }
    # Construct the replacement and capture rollback data before stopping anything.
    $executable=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $arguments="-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$destination\reconnect-client.ps1`" -Server $Server -ReceiveMode $ReceiveMode -BusIDs $BusIDs"
    $action=New-ScheduledTaskAction -Execute $executable -Argument $arguments -WorkingDirectory $destination
    $principal=New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $trigger=New-ScheduledTaskTrigger -AtStartup
    $settings=New-ScheduledTaskSettingsSet -StartWhenAvailable -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    $existing=Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existing) {
        $previousXML=Export-ScheduledTask -TaskName $taskName
        $wasRunning=$existing.State -in @('Running','Queued')
    }
    $taskTouched=$true
    if ($existing) { Stop-ScheduledTask -TaskName $taskName }
    foreach ($logName in @('reconnect.log','reconnect.log.1')) {
        $oldLog=Join-Path $destination $logName
        if (Test-Path -LiteralPath $oldLog -PathType Leaf) {
            Copy-Item -LiteralPath $oldLog -Destination (Join-Path $staging $logName)
        }
    }
    if (Test-Path -LiteralPath $destination) {
        Move-InstallationDirectory $destination $backup
        $oldMoved=$true
    }
    # Each rename moves a complete directory on the same volume; files never mix.
    Move-InstallationDirectory $staging $destination
    $newMoved=$true
    Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Trigger $trigger -Settings $settings -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName
    $committed=$true
} catch {
    $failure=$_
    $recoveryErrors=@()
    if ($taskTouched) {
        try {
            if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) { Stop-ScheduledTask -TaskName $taskName }
        } catch { $recoveryErrors+='Could not stop replacement task: '+$_.Exception.Message }
        try {
            if ($newMoved) { Move-InstallationDirectory $destination $failed }
            if ($oldMoved) { Move-InstallationDirectory $backup $destination }
        } catch { $recoveryErrors+='Could not restore files: '+$_.Exception.Message }
        try {
            if ($previousXML) {
                Register-ScheduledTask -TaskName $taskName -Xml $previousXML -Force | Out-Null
                # Do not run an old task against replacement files after failed rollback.
                if ($wasRunning -and (-not $oldMoved -or -not (Test-Path -LiteralPath $backup))) {
                    Start-ScheduledTask -TaskName $taskName
                }
            } elseif (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            }
        } catch { $recoveryErrors+='Could not restore task: '+$_.Exception.Message }
    }
    if ($recoveryErrors.Count -gt 0) {
        throw ($failure.Exception.Message+' Rollback needs attention: '+($recoveryErrors -join '; ')+". Recovery files: $backup; $failed")
    }
    $rollbackComplete=$true
    throw $failure
} finally {
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue }
    if ($committed -and (Test-Path -LiteralPath $backup)) {
        Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($rollbackComplete -and (Test-Path -LiteralPath $failed)) { Remove-Item -LiteralPath $failed -Recurse -Force -ErrorAction SilentlyContinue }
    if ($installationOwned) { $installationMutex.ReleaseMutex() }
    $installationMutex.Dispose()
}
'Installed persistent Windows reconnect helper. No account password is stored.'
