# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
param([int]$Seconds=20,[string]$OutputFile='')
$ErrorActionPreference='Stop'
if(-not ('XInputProbe' -as [type])){Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class XInputProbe {
    [StructLayout(LayoutKind.Sequential)] public struct Gamepad {
        public ushort buttons; public byte leftTrigger,rightTrigger;
        public short leftX,leftY,rightX,rightY;
    }
    [StructLayout(LayoutKind.Sequential)] public struct State {public uint packet;public Gamepad gamepad;}
    [DllImport("xinput1_4.dll")] public static extern uint XInputGetState(uint index,out State state);
}
'@}
$slots=@{}
for($index=0;$index -lt 4;$index++){$slots[$index]=@{reads=0;notConnected=0;states=(New-Object 'System.Collections.Generic.HashSet[string]');buttons=[uint16]0}}
$clock=[Diagnostics.Stopwatch]::StartNew()
while($clock.Elapsed.TotalSeconds -lt $Seconds){
    for([uint32]$index=0;$index -lt 4;$index++){
        $state=New-Object XInputProbe+State
        $slot=$slots[[int]$index]
        if([XInputProbe]::XInputGetState($index,[ref]$state) -eq 0){
            $slot.reads++;$g=$state.gamepad;$slot.buttons=$slot.buttons -bor $g.buttons
            # Do not include packet counters: heartbeat changes are not proof of input.
            [void]$slot.states.Add((@($g.buttons,$g.leftTrigger,$g.rightTrigger,$g.leftX,$g.leftY,$g.rightX,$g.rightY)-join ','))
        }else{$slot.notConnected++}
    }
    Start-Sleep -Milliseconds 10
}
$result=@()
foreach($index in 0..3){$slot=$slots[[int]$index];$result+=[ordered]@{slot=$index;reads=$slot.reads;notConnected=$slot.notConnected;distinctInputStates=$slot.states.Count;buttonsSeen=('0x{0:x4}'-f $slot.buttons)}}
$json=([ordered]@{seconds=[Math]::Round($clock.Elapsed.TotalSeconds,2);slots=$result}|ConvertTo-Json -Depth 4)
if($OutputFile){$json|Set-Content -Encoding UTF8 $OutputFile}
$json
