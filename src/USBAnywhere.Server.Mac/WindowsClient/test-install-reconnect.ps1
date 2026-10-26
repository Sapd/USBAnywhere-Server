# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
#Requires -Version 5.1
# Transaction tests use actual temporary files and mocked ScheduledTasks functions.
# No real scheduled task, driver, installed directory, or reconnect worker is changed.
$ErrorActionPreference='Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run this test with Windows PowerShell 5.1 (powershell.exe)' }
$testIdentity=[Security.Principal.WindowsIdentity]::GetCurrent()
if (-not ([Security.Principal.WindowsPrincipal]::new($testIdentity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'This test preserves the installer administrator check; run elevated Windows PowerShell'
}
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('USBAnywhereInstallerTest-'+[Guid]::NewGuid().ToString('N'))
$testOriginalProgramFiles=$env:ProgramFiles
try {
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    foreach ($testScenario in @('invalid-arguments','missing-late-file','success','late-register-failure','initial-register-failure')) {
        & {
            param($testScenario,$testRoot,$testSource)
            $testCase=Join-Path $testRoot $testScenario
            $testPackage=Join-Path $testCase 'Package'
            $testProgramFiles=Join-Path $testCase 'ProgramFiles'
            New-Item -ItemType Directory -Path $testPackage,$testProgramFiles | Out-Null
            $testInstalled=Join-Path $testProgramFiles 'USBAnywhereMacClient'
            $testNames=@('usbip.exe','usbipw.exe','libusbip.dll','resources.dll','usb.ids','reconnect-client.ps1','client-discovery.ps1')
            foreach ($testName in $testNames) {
                $testPath=Join-Path $testPackage $testName
                if ([IO.Path]::GetExtension($testName) -in @('.exe','.dll')) {
                    $testBytes=New-Object byte[] 128
                    $testBytes[0]=77; $testBytes[1]=90; $testBytes[2]=42
                    [IO.File]::WriteAllBytes($testPath,$testBytes)
                } elseif ($testName -eq 'usb.ids') {
                    [IO.File]::WriteAllText($testPath,'1234  Isolated test device')
                } else { Copy-Item -LiteralPath (Join-Path $testSource $testName) -Destination $testPath }
            }
            $testInstaller=Join-Path $testPackage 'install-reconnect-client.ps1'
            $testInstallerSource=[IO.File]::ReadAllText((Join-Path $testSource 'install-reconnect-client.ps1'))
            # Keep even the installer mutex isolated from any real installation.
            $testMutex='Local\USBAnywhereInstallerTest-'+[Guid]::NewGuid().ToString('N')
            if (-not $testInstallerSource.Contains('Global\USBAnywhereMacReconnectInstall')) { throw 'Installer mutex fixture no longer matches' }
            [IO.File]::WriteAllText($testInstaller,$testInstallerSource.Replace('Global\USBAnywhereMacReconnectInstall',$testMutex))
            $testHasOld=$testScenario -ne 'initial-register-failure'
            if ($testHasOld) {
                New-Item -ItemType Directory -Path $testInstalled | Out-Null
                foreach ($testName in ($testNames+@('old-only.dat','reconnect.log','reconnect.log.1'))) {
                    [IO.File]::WriteAllText((Join-Path $testInstalled $testName),('original bytes: '+$testName))
                }
            }
            function Get-TestFiles([string]$Path) {
                if (-not (Test-Path -LiteralPath $Path)) { return @() }
                return @(Get-ChildItem -LiteralPath $Path -File -Recurse | ForEach-Object {
                    $_.FullName.Substring($Path.Length+1)+'|'+(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
                } | Sort-Object)
            }
            $testBefore=@(Get-TestFiles $testInstalled)
            $testState=@{
                Mode='MockScheduledTasksOnly'; Exists=$testHasOld; Running=$testHasOld;
                XML='<Task>original task XML</Task>'; Events=[Collections.Generic.List[string]]::new();
                FailRegistration=($testScenario -in @('late-register-failure','initial-register-failure'))
            }
            function Assert-TestMock {
                if ($testState.Mode -ne 'MockScheduledTasksOnly') { throw 'Mock-only task guard failed' }
            }
            function New-ScheduledTaskAction {
                [CmdletBinding()]param($Execute,$Argument,$WorkingDirectory)
                Assert-TestMock; $testState.Events.Add('NewAction')
                [pscustomobject]@{Execute=$Execute;Arguments=$Argument;WorkingDirectory=$WorkingDirectory}
            }
            function New-ScheduledTaskPrincipal {
                [CmdletBinding()]param($UserId,$LogonType,$RunLevel)
                Assert-TestMock; $testState.Events.Add('NewPrincipal'); [pscustomobject]@{UserId=$UserId}
            }
            function New-ScheduledTaskTrigger {
                [CmdletBinding()]param([switch]$AtStartup)
                Assert-TestMock; $testState.Events.Add('NewTrigger'); [pscustomobject]@{AtStartup=$AtStartup}
            }
            function New-ScheduledTaskSettingsSet {
                [CmdletBinding()]param([switch]$StartWhenAvailable,$RestartCount,$RestartInterval,$ExecutionTimeLimit,$MultipleInstances,
                    [switch]$AllowStartIfOnBatteries,[switch]$DontStopIfGoingOnBatteries)
                Assert-TestMock; $testState.Events.Add('NewSettings'); [pscustomobject]@{RestartCount=$RestartCount}
            }
            function Get-ScheduledTask {
                [CmdletBinding()]param($TaskName)
                Assert-TestMock; $testState.Events.Add('Get')
                if ($testState.Exists) { [pscustomobject]@{TaskName=$TaskName;State=$(if($testState.Running){'Running'}else{'Ready'})} }
            }
            function Export-ScheduledTask {
                [CmdletBinding()]param($TaskName)
                Assert-TestMock; $testState.Events.Add('Export'); $testState.XML
            }
            function Stop-ScheduledTask {
                [CmdletBinding()]param($TaskName)
                Assert-TestMock; $testState.Events.Add('Stop'); $testState.Running=$false
            }
            function Register-ScheduledTask {
                [CmdletBinding()]param($TaskName,$Action,$Principal,$Trigger,$Settings,$Xml,[switch]$Force)
                Assert-TestMock
                $testState.Exists=$true; $testState.Running=$false
                if ($Xml) { $testState.Events.Add('RestoreXML'); $testState.XML=$Xml }
                else {
                    $testState.Events.Add('RegisterNew'); $testState.XML='<Task>replacement task XML</Task>'
                    if ($testState.FailRegistration) {
                        $testState.FailRegistration=$false
                        # Simulate registration changing task state before reporting failure.
                        throw 'Injected late registration failure'
                    }
                }
            }
            function Start-ScheduledTask {
                [CmdletBinding()]param($TaskName)
                Assert-TestMock; $testState.Events.Add('Start')
                if (-not $testState.Exists) { throw 'Mock attempted to start an absent task' }
                $testState.Running=$true
            }
            function Unregister-ScheduledTask {
                [CmdletBinding()]param($TaskName,[switch]$Confirm)
                Assert-TestMock; $testState.Events.Add('Unregister'); $testState.Exists=$false; $testState.Running=$false
            }
            $testCommands=@('New-ScheduledTaskAction','New-ScheduledTaskPrincipal','New-ScheduledTaskTrigger','New-ScheduledTaskSettingsSet',
                'Get-ScheduledTask','Export-ScheduledTask','Stop-ScheduledTask','Register-ScheduledTask','Start-ScheduledTask','Unregister-ScheduledTask')
            foreach ($testCommand in $testCommands) {
                if ((Get-Command $testCommand).CommandType -ne 'Function') { throw ('Unsafe unmocked task command: '+$testCommand) }
            }
            if ($testScenario -eq 'missing-late-file') { Remove-Item -LiteralPath (Join-Path $testPackage 'reconnect-client.ps1') }
            $env:ProgramFiles=$testProgramFiles
            $testFailure=$null
            try {
                $testBusIDs=if($testScenario -eq 'invalid-arguments'){'1-99'}else{'auto'}
                $null=. $testInstaller -Server 127.0.0.7 -ReceiveMode zero-copy -BusIDs $testBusIDs
            } catch { $testFailure=$_ }
            if ($testScenario -eq 'success') {
                if ($testFailure) { throw $testFailure }
                if (-not $testState.Exists -or -not $testState.Running -or $testState.XML -ne '<Task>replacement task XML</Task>') { throw 'Replacement task state was not committed' }
                foreach ($testName in $testNames) {
                    if ((Get-FileHash (Join-Path $testPackage $testName)).Hash -ne (Get-FileHash (Join-Path $testInstalled $testName)).Hash) {
                        throw ('Replacement file differs: '+$testName)
                    }
                }
                foreach ($testName in @('reconnect.log','reconnect.log.1')) {
                    if ([IO.File]::ReadAllText((Join-Path $testInstalled $testName)) -ne ('original bytes: '+$testName)) { throw 'Existing logs were not preserved' }
                }
                if (Test-Path -LiteralPath (Join-Path $testInstalled 'old-only.dat')) { throw 'Successful replacement retained an obsolete file' }
            } else {
                if (-not $testFailure) { throw ('Expected installer failure for '+$testScenario) }
                $testExpected=if($testScenario -eq 'invalid-arguments'){'Bus IDs must be between'}elseif($testScenario -eq 'missing-late-file'){'Missing client file'}else{'Injected late registration failure'}
                if ($testFailure.Exception.Message -notlike ('*'+$testExpected+'*')) { throw ('Unexpected failure for '+$testScenario+': '+$testFailure.Exception.Message) }
                if ($testHasOld) {
                    if ((@(Get-TestFiles $testInstalled) -join "`n") -cne ($testBefore -join "`n")) { throw 'Rollback changed original file bytes or membership' }
                    if (-not $testState.Exists -or -not $testState.Running -or $testState.XML -ne '<Task>original task XML</Task>') { throw 'Rollback did not restore the original XML/running state' }
                } else {
                    if ($testState.Exists -or (Test-Path -LiteralPath $testInstalled)) { throw 'Failed first installation left task or installed files behind' }
                    if (-not $testState.Events.Contains('Unregister')) { throw 'Failed first installation did not remove its partial task' }
                }
                if ($testScenario -in @('invalid-arguments','missing-late-file') -and $testState.Events.Count -ne 0) { throw 'Invalid/staging-failed request touched scheduled tasks' }
            }
            $testLeftovers=@(Get-ChildItem -LiteralPath $testProgramFiles | Where-Object { $_.Name -match '\.(staging|backup|failed)-' })
            if ($testLeftovers.Count -ne 0) { throw 'Transaction left staging/backup/failed directories behind' }
            'PASS: isolated installer transaction '+$testScenario
        } $testScenario $testRoot $PSScriptRoot
    }
} finally {
    $env:ProgramFiles=$testOriginalProgramFiles
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
