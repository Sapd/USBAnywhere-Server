# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
param([Parameter(Mandatory=$true)][string]$Server)
$ErrorActionPreference = 'Stop'
function Read-Exact($stream, [int]$length) {
    $buffer = New-Object byte[] $length
    $offset = 0
    while ($offset -lt $length) {
        $count = $stream.Read($buffer,$offset,$length-$offset)
        if ($count -le 0) { throw 'Unexpected end of USB/IP response' }
        $offset += $count
    }
    return ,$buffer
}
function Put-U32([byte[]]$buffer, [int]$offset, [uint32]$number) {
    $bytes = [BitConverter]::GetBytes($number)
    [Array]::Reverse($bytes)
    $bytes.CopyTo($buffer,$offset)
}
function Import-Device {
    $client = [Net.Sockets.TcpClient]::new()
    try {
        $client.Connect($Server,3240)
        $client.ReceiveTimeout=8000; $client.SendTimeout=5000
        $request = New-Object byte[] 40
        ([byte[]](1,17,128,3,0,0,0,0)).CopyTo($request,0)
        [Text.Encoding]::ASCII.GetBytes('1-1').CopyTo($request,8)
        $stream = $client.GetStream(); $stream.Write($request,0,40)
        $reply = Read-Exact $stream 8
        if ($reply[3] -ne 3 -or $reply[7] -ne 0) { throw 'USB import failed during recovery test' }
        $null = Read-Exact $stream 312
        return $client
    } catch { $client.Dispose(); throw }
}
function New-Submit {
    $header = New-Object byte[] 48
    Put-U32 $header 0 1; Put-U32 $header 4 1; Put-U32 $header 8 65537
    Put-U32 $header 12 1; Put-U32 $header 16 1; Put-U32 $header 24 64
    Put-U32 $header 32 ([uint32]::MaxValue)
    return ,$header
}
function Test-RawInput($client) {
    $stream = $client.GetStream(); $submit = New-Submit; $stream.Write($submit,0,48)
    $reply = Read-Exact $stream 48
    if ($reply[3] -ne 3 -or $reply[23] -ne 0 -or $reply[27] -ne 64) { throw 'Physical USB interrupt read failed' }
    $report = Read-Exact $stream 64
    if ($report[0] -ne 1) { throw 'Unexpected joystick input report ID' }
}

function Invoke-HaltControl($client,[bool]$setHalt) {
    $h=New-Submit
    Put-U32 $h 12 0; Put-U32 $h 16 0; Put-U32 $h 24 0
    $h[40]=2; $h[41]=$(if($setHalt){3}else{1}); $h[44]=129
    $stream=$client.GetStream();$stream.Write($h,0,48)
    $reply=Read-Exact $stream 48
    return [Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($reply,20))
}
$client=Import-Device
try {
    Test-RawInput $client
    $status=Invoke-HaltControl $client $true
    if($status -ne 0){throw "SET_FEATURE endpoint halt failed: $status"}
    $stream=$client.GetStream();$h=New-Submit;$stream.Write($h,0,48)
    $reply=Read-Exact $stream 48
    $status=[Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($reply,20))
    if($status -ne -32){throw "Expected EPIPE (-32) for actual halted endpoint, got $status"}
    $status=Invoke-HaltControl $client $false
    if($status -ne 0){throw "CLEAR_FEATURE endpoint recovery failed: $status"}
    Test-RawInput $client
    'PASS: physical endpoint halt returned EPIPE, explicit clear-halt restored USB input in the same session'
    $status=Invoke-HaltControl $client $true
    if($status -ne 0){throw "Second SET_FEATURE endpoint halt failed: $status"}
    $h=New-Submit; Put-U32 $h 4 2; Put-U32 $h 12 0; Put-U32 $h 16 0; Put-U32 $h 24 0
    $h[40]=0; $h[41]=9; $h[42]=1
    $stream.Write($h,0,48)
    $reply=Read-Exact $stream 48
    $status=[Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($reply,20))
    if($status -ne 0){throw "SET_CONFIGURATION reset failed: $status"}
    Test-RawInput $client
    'PASS: repeated SET_CONFIGURATION cleared a physical endpoint halt and restored input without reimport'
    $status=Invoke-HaltControl $client $true
    if($status -ne 0){throw "Third SET_FEATURE endpoint halt failed: $status"}
    $h=New-Submit; Put-U32 $h 4 3; Put-U32 $h 12 0; Put-U32 $h 16 0; Put-U32 $h 24 0
    $h[40]=1; $h[41]=11
    $stream.Write($h,0,48)
    $reply=Read-Exact $stream 48
    $status=[Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($reply,20))
    if($status -eq -32) {
        # USB 2.0 allows a device with only the default alternate to STALL this
        # request. The server must propagate it and release the failed capture.
        $client.Dispose()
        Start-Sleep -Seconds 1
        $client=Import-Device
        Test-RawInput $client
        'PASS: VKB rejected optional SET_INTERFACE(0) with EPIPE; fresh import restored physical input'
    } elseif($status -ne 0) { throw "SET_INTERFACE(0) reset failed: $status" }
    else {
        Test-RawInput $client
        'PASS: SET_INTERFACE(0) cleared a physical endpoint halt and rebuilt usable pipes without reimport'
    }


} finally { $client.Dispose() }
