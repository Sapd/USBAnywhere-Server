# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
param([int]$Seconds=20,[string]$OutputFile='',[string]$StopFile='')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'controller-api.ps1')
$sticks=@{}
for([uint32]$slot=0;$slot -lt 16;$slot++) {
    $caps=New-Object VKBNative+Caps
    $state=New-Object VKBNative+State; $state.size=[Runtime.InteropServices.Marshal]::SizeOf($state); $state.flags=255
    if([VKBNative]::joyGetDevCaps($slot,[ref]$caps,[Runtime.InteropServices.Marshal]::SizeOf($caps)) -eq 0 -and
       $caps.vendor -eq 0x231d -and $caps.product -in @(0x0201,0x0200) -and [VKBNative]::joyGetPosEx($slot,[ref]$state) -eq 0) {
        $side=if($caps.product -eq 0x0201){'left'}else{'right'}
        if($sticks.ContainsKey($side)){ throw "Duplicate live $side VKB joystick in Windows" }
        $sticks[$side]=@{slot=$slot;product=('{0:x4}' -f $caps.product);samples=0;failures=0;buttons=[uint32]0;mins=@(65535,65535,65535,65535,65535,65535);maxs=@(0,0,0,0,0,0);states=(New-Object 'System.Collections.Generic.HashSet[string]')}
    }
}
if($sticks.Count -ne 2){throw 'Both left and right VKB sticks must be attached and readable'}
$clock=[Diagnostics.Stopwatch]::StartNew()
while($clock.Elapsed.TotalSeconds -lt $Seconds) {
    if($StopFile -and (Test-Path $StopFile)){break}
    foreach($side in @('left','right')) {
        $stick=$sticks[$side]; $state=New-Object VKBNative+State
        $state.size=[Runtime.InteropServices.Marshal]::SizeOf($state); $state.flags=255
        if([VKBNative]::joyGetPosEx($stick.slot,[ref]$state) -eq 0) {
            $stick.samples++
            $values=@($state.x,$state.y,$state.z,$state.r,$state.u,$state.v)
            for($i=0;$i -lt 6;$i++){ $stick.mins[$i]=[Math]::Min($stick.mins[$i],$values[$i]); $stick.maxs[$i]=[Math]::Max($stick.maxs[$i],$values[$i]) }
            $stick.buttons=$stick.buttons -bor $state.buttons
            [void]$stick.states.Add(($values -join ',')+':'+$state.buttons+':'+$state.pov)
        } else { $stick.failures++ }
    }
    Start-Sleep -Milliseconds 10
}
$direct=@([VKBNative]::DirectInputDevices() | ForEach-Object {
    $id=[BitConverter]::ToUInt32($_.product.ToByteArray(),0)
    if(($id -band 65535) -eq 0x231d){[ordered]@{product=('{0:x4}' -f ($id -shr 16));instanceGuid=$_.instance.ToString();productName=$_.productName;instanceName=$_.instanceName}}
})
$result=[ordered]@{seconds=[Math]::Round($clock.Elapsed.TotalSeconds,2);directInput=$direct;sticks=@();usbInstanceIds=@()}
foreach($side in @('left','right')) {
    $stick=$sticks[$side]
    $result.sticks+= [ordered]@{side=$side;product=$stick.product;windowsSlot=$stick.slot;samples=$stick.samples;failures=$stick.failures;distinctStates=$stick.states.Count;axisMinimums=$stick.mins;axisMaximums=$stick.maxs;buttonsSeen=('0x{0:x8}' -f $stick.buttons)}
}
$result.usbInstanceIds=@(Get-PnpDevice -PresentOnly | Where-Object {$_.InstanceId -match '^USB\\VID_231D&PID_020[01]\\'} | Select-Object -ExpandProperty InstanceId)
$json=$result | ConvertTo-Json -Depth 6
if($OutputFile){$json | Set-Content -Encoding UTF8 $OutputFile}
$json
if(@($sticks.Values | Where-Object {$_.failures -gt 0 -or ($Seconds -gt 0 -and $_.samples -eq 0)}).Count -gt 0){exit 1}
