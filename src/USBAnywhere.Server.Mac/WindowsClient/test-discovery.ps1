# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'client-discovery.ps1')
$sample=@'
Exportable USB devices
======================
    1-4    : Tobii Technology AB : EyeChip (2104:0313)
           : /macos/identity/TOBII0313
    1-1    : VKB (231d:0201)
    1-5    : New device (1234:5678)
    1-1    : repeated
'@
$ids=@(Get-ExportedBusIDs $sample)
if(($ids -join ',') -ne '1-1,1-4,1-5'){throw 'Discovery ordering/duplicates failed'}
if(@(Get-ExportedBusIDs "Exportable USB devices`n===`n").Count -ne 0){throw 'Empty export response failed'}
$rejected=$false;try {Get-ExportedBusIDs 'connection failed'}catch{$rejected=$true};if(-not $rejected){throw 'Invalid output accepted'}
$rejected=$false;try {Get-ExportedBusIDs "Exportable USB devices`n1-99 : bad"}catch{$rejected=$true};if(-not $rejected){throw 'Out-of-range bus accepted'}
if ((@(Get-RequestedBusIDs '1-1,1-16') -join ',') -ne '1-1,1-16') { throw 'Explicit bus-ID bounds rejected' }
if (@(Get-RequestedBusIDs 'auto').Count -ne 0) { throw 'Automatic selection should start empty' }
foreach ($invalid in @('1-1,1-1','1-0','1-17','1-99','1-01','1-1,1-16,1-1','')) {
    $rejected=$false
    try { $null=@(Get-RequestedBusIDs $invalid) } catch { $rejected=$true }
    if (-not $rejected) { throw "Invalid explicit bus IDs accepted: $invalid" }
}
'PASS: discovery ordering, duplicates, empty responses and explicit bus-ID uniqueness/canonical bounds'
