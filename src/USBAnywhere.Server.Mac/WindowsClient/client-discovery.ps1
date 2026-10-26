# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
# Copyright 2026 Denis Arnst (Sapd) — https://github.com/Sapd
# GPL-3.0. Parse only the Mac server's bounded, fixed bus-ID namespace.
function Get-RequestedBusIDs([string]$BusIDs) {
    if ($BusIDs -eq 'auto') { return @() }
    $ids=@($BusIDs.Split(','))
    if ($ids.Count -gt 16 -or @($ids | Select-Object -Unique).Count -ne $ids.Count) {
        throw 'Bus IDs must be unique, with at most 16 devices'
    }
    foreach ($id in $ids) {
        if ($id -notmatch '^1-([1-9]|1[0-6])$') { throw 'Bus IDs must be between 1-1 and 1-16' }
    }
    return $ids
}
function Get-ExportedBusIDs([string]$Output) {
    if ($Output -notmatch '(?m)^\s*Exportable USB devices\s*$') { throw 'Unrecognized USB/IP discovery response' }
    $found=@()
    foreach($line in ($Output -split "`r?`n")) {
        if($line -match '^\s*(1-([0-9]{1,2}))\s+:') {
            $number=[int]$Matches[2]
            if($number -lt 1 -or $number -gt 16) { throw 'Out-of-range device bus ID' }
            $found += $Matches[1]
        }
    }
    return @($found | Select-Object -Unique | Sort-Object { [int]($_.Substring(2)) })
}
