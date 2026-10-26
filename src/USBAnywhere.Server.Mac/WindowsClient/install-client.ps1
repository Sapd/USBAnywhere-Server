# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
# Run in an elevated PowerShell from the USBAnywhere Portable directory.
$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run PowerShell as administrator'
}
$catalog = Join-Path $PSScriptRoot 'drivers\usbip2_ude.cat'
if ((Get-AuthenticodeSignature $catalog).Status -ne 'Valid') { throw 'Driver catalog signature is not valid' }
$controllers = @(Get-CimInstance Win32_PnPEntity -Filter "PNPClass='USB'" |
    Where-Object { $_.HardwareID -contains 'ROOT\USBIP_WIN2\UDE' })
if ($controllers.Count -gt 1) { throw 'Multiple USB/IP controllers exist. Resolve duplicates before installing.' }
if ($controllers.Count -eq 0) {
    & (Join-Path $PSScriptRoot 'devnode.exe') install (Join-Path $PSScriptRoot 'drivers\usbip2_ude.inf') 'ROOT\USBIP_WIN2\UDE'
    if ($LASTEXITCODE -ne 0) { throw "Driver installation failed: $LASTEXITCODE" }
} else { Write-Output 'USB/IP controller already installed; reusing it.' }
& (Join-Path $PSScriptRoot 'usbip.exe') port
if ($LASTEXITCODE -ne 0) { throw "USB/IP controller check failed: $LASTEXITCODE" }
