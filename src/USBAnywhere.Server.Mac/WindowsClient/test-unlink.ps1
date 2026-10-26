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

# Detach bus 1-1 and stop the reconnect task before running this hardware test.
# It changes only request lifetime, never device firmware or persistent settings.
$client=Import-Device
try {
    $stream=$client.GetStream()
    $cancelled=0
    for ($cycle=0; $cycle -lt 100; $cycle++) {
        $first=[uint32](3*$cycle+1); $second=$first+1; $unlink=$first+2
        $a=New-Submit; Put-U32 $a 4 $first
        $b=New-Submit; Put-U32 $b 4 $second
        $u=New-Object byte[] 48
        Put-U32 $u 0 2; Put-U32 $u 4 $unlink; Put-U32 $u 8 65537; Put-U32 $u 20 $first
        $batch=New-Object byte[] 144
        $a.CopyTo($batch,0); $b.CopyTo($batch,48); $u.CopyTo($batch,96)
        $stream.Write($batch,0,$batch.Length)
        $sawSecond=$false; $sawUnlink=$false; $sawFirst=$false
        while (-not ($sawSecond -and $sawUnlink)) {
            $reply=Read-Exact $stream 48
            $command=[Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($reply,0))
            $seq=[Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($reply,4))
            $status=[Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($reply,20))
            if ($command -eq 4 -and $seq -eq $unlink) {
                if ($status -eq -104) { $cancelled++; if ($sawFirst) { throw 'Cancelled request also completed' } }
                elseif ($status -ne 0 -or -not $sawFirst) { throw "Unexpected unlink result: $status" }
                $sawUnlink=$true
            } elseif ($command -eq 3 -and ($seq -eq $first -or $seq -eq $second)) {
                $length=[Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($reply,24))
                if ($status -ne 0 -or $length -ne 64) { throw "Input request $seq failed after unlink: status=$status length=$length" }
                $report=Read-Exact $stream $length
                if ($report[0] -ne 1) { throw 'Unexpected joystick report' }
                if ($seq -eq $first) { $sawFirst=$true } else { $sawSecond=$true }
            } else { throw "Unexpected response: command=$command seq=$seq" }
        }
    }
    if ($cancelled -eq 0) { throw 'All requests completed before unlink: native cancellation was not exercised' }
    Test-RawInput $client
    "PASS: 100 same-endpoint request pairs; $cancelled active/queued cancellations; unrelated reads and final physical input remained usable"
} finally { $client.Dispose() }
