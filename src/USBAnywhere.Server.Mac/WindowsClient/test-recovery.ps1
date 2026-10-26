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
for ($cycle=1; $cycle -le 10; $cycle++) {
    $client = Import-Device
    try {
        if ($cycle -eq 1) { Start-Sleep -Seconds 7 }
        Test-RawInput $client
        $client.LingerState = [Net.Sockets.LingerOption]::new($true,0)
    } finally { $client.Dispose() }
    Start-Sleep -Milliseconds 700
    "PASS: abrupt reset/reimport $cycle/10 with physical USB read"
}
foreach ($fault in @('partial-header','missing-out-payload','oversized-buffer','wrong-device')) {
    $client = Import-Device
    try {
        $stream = $client.GetStream()
        $header = New-Submit
        if ($fault -eq 'partial-header') { $stream.WriteByte(0) }
        else {
            if ($fault -eq 'missing-out-payload') { Put-U32 $header 12 0 }
            if ($fault -eq 'oversized-buffer') { Put-U32 $header 24 1048577 }
            if ($fault -eq 'wrong-device') { Put-U32 $header 8 65538 }
            $stream.Write($header,0,48)
        }
        $clock = [Diagnostics.Stopwatch]::StartNew()
        if ($stream.ReadByte() -ne -1) { throw "Fault $fault did not close the session" }
        if ($clock.Elapsed.TotalSeconds -gt 7) { throw "Fault $fault exceeded recovery deadline" }
    } finally { $client.Dispose() }
    Start-Sleep -Milliseconds 700
    $client = Import-Device
    try { Test-RawInput $client } finally { $client.Dispose() }
    Start-Sleep -Milliseconds 700
    "PASS: $fault releases capture and allows a new physical USB read"
}
'PASS: idle session, 10 abrupt resets and four fault recovery cases'
