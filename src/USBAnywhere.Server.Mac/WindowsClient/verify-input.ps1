# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
param([int]$Seconds = 20)
$ErrorActionPreference = 'Stop'
if (-not ('JoystickProbe' -as [type])) { Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class JoystickProbe {
    [StructLayout(LayoutKind.Sequential)]
    public struct State {
        public uint size, flags, x, y, z, r, u, v, buttons, buttonNumber, pov, reserved1, reserved2;
    }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    public struct Caps {
        public ushort vendor, product;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string name;
        public uint xmin,xmax,ymin,ymax,zmin,zmax,buttons,periodmin,periodmax;
        public uint rmin,rmax,umin,umax,vmin,vmax,capabilities,maxAxes,axes,maxButtons;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string registryKey;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=260)] public string oem;
    }
    [DllImport("winmm.dll")] public static extern uint joyGetPosEx(uint id, ref State state);
    [DllImport("winmm.dll", EntryPoint="joyGetDevCapsW")] public static extern uint joyGetDevCaps(uint id, out Caps caps, uint size);
}
'@
}
$target = $null
for ([uint32]$id = 0; $id -lt 16; $id++) {
    $caps = New-Object JoystickProbe+Caps
    if ([JoystickProbe]::joyGetDevCaps($id, [ref]$caps, [Runtime.InteropServices.Marshal]::SizeOf($caps)) -eq 0) {
        if ($caps.vendor -eq 0x231d -and $caps.product -eq 0x0201) { $target = $id; break }
    }
}
if ($null -eq $target) { throw 'VKB joystick not found through the Windows joystick API' }
$seen = New-Object 'System.Collections.Generic.HashSet[string]'
$mins = @(65535,65535,65535,65535,65535,65535)
$maxs = @(0,0,0,0,0,0)
[uint32]$buttonsSeen = 0
$samples = 0
$failures = 0
$clock = [Diagnostics.Stopwatch]::StartNew()
while ($clock.Elapsed.TotalSeconds -lt $Seconds) {
    $state = New-Object JoystickProbe+State
    $state.size = [Runtime.InteropServices.Marshal]::SizeOf($state)
    $state.flags = 255
    if ([JoystickProbe]::joyGetPosEx($target, [ref]$state) -eq 0) {
        $samples++
        $values = @($state.x,$state.y,$state.z,$state.r,$state.u,$state.v)
        for ($i=0; $i -lt 6; $i++) {
            $mins[$i] = [Math]::Min($mins[$i], $values[$i])
            $maxs[$i] = [Math]::Max($maxs[$i], $values[$i])
        }
        $buttonsSeen = $buttonsSeen -bor $state.buttons
        [void]$seen.Add(($values -join ',') + ':' + $state.buttons + ':' + $state.pov)
    } else { $failures++ }
    Start-Sleep -Milliseconds 10
}
[ordered]@{
    name = $caps.name; vendor = ('{0:x4}' -f $caps.vendor); product = ('{0:x4}' -f $caps.product)
    axes = $caps.axes; buttonsExposedToWinMM = $caps.buttons
    durationSeconds = [Math]::Round($clock.Elapsed.TotalSeconds,2)
    samples = $samples; readFailures = $failures; distinctStates = $seen.Count
    axisMinimums = $mins; axisMaximums = $maxs; buttonsSeen = ('0x{0:x8}' -f $buttonsSeen)
} | ConvertTo-Json -Depth 3
if ($samples -eq 0 -or $failures -gt 0) { exit 1 }
