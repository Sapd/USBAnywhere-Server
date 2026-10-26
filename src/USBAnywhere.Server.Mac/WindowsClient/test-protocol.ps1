# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
param([Parameter(Mandatory=$true)][string]$Server)
$ErrorActionPreference = 'Stop'
function Connect-Server {
    $client = [Net.Sockets.TcpClient]::new()
    $client.Connect($Server,3240)
    $client.ReceiveTimeout = 5000
    $client.SendTimeout = 5000
    return $client
}
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
$list = [byte[]](1,17,128,5,0,0,0,0)
$import = [byte[]](1,17,128,3,0,0,0,0)
$client = Connect-Server
try {
    $stream = $client.GetStream()
    foreach ($byte in $list) { $stream.WriteByte($byte) }
    $reply = Read-Exact $stream 12
    $count=[int]$reply[8]*16777216+[int]$reply[9]*65536+[int]$reply[10]*256+[int]$reply[11]
    if ($reply[3] -ne 5 -or $count -lt 1 -or $count -gt 16) { throw 'Invalid device-list reply' }
    $found=$false
    for($index=0;$index -lt $count;$index++) {
        $device = Read-Exact $stream 312
        $interfaces = Read-Exact $stream ($device[311]*4)
        if ($device[300] -eq 0x23 -and $device[301] -eq 0x1d -and $device[302] -eq 2 -and $device[303] -eq 1) {
            if ($interfaces[0] -ne 3) { throw 'Expected a physical HID interface' }
            $found=$true
        }
    }
    if(-not $found){throw 'Configured left VKB device is missing from the device list'}
    'PASS: fragmented device-list request, original VID/PID and HID interface'
} finally { $client.Dispose() }
$client = Connect-Server
try {
    $stream = $client.GetStream()
    $stream.Write($import,0,8)
    $wrong = New-Object byte[] 32
    [Text.Encoding]::ASCII.GetBytes('not-exported').CopyTo($wrong,0)
    $stream.Write($wrong,0,32)
    $reply = Read-Exact $stream 8
    if ($reply[3] -ne 3 -or $reply[7] -eq 0) { throw 'Unknown bus ID was accepted' }
    'PASS: unknown bus ID refused without capturing another device'
} finally { $client.Dispose() }
$client = Connect-Server
try {
    $stream = $client.GetStream()
    $invalidVersion = [byte[]](0,0,128,5,0,0,0,0)
    $stream.Write($invalidVersion,0,8)
    if ($stream.ReadByte() -ne -1) { throw 'Invalid protocol version was accepted' }
    'PASS: invalid protocol version rejected'
} finally { $client.Dispose() }
$client = Connect-Server
$client.GetStream().WriteByte(1)
$client.Dispose()
$client = Connect-Server
try {
    $stream = $client.GetStream(); $stream.Write($list,0,8)
    $reply = Read-Exact $stream 12
    if ($reply[11] -lt 1) { throw 'Server did not recover from truncated request' }
    'PASS: truncated request does not affect subsequent connections'
} finally { $client.Dispose() }
