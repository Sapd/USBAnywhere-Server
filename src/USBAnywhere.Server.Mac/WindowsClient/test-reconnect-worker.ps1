# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
#Requires -Version 5.1
# Safe integration test: only temporary files and a temporary fake executable.
# Run with Windows PowerShell 5.1; no administrator, driver, network or task changes.
$ErrorActionPreference='Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run this test with Windows PowerShell 5.1 (powershell.exe)' }
$root=Join-Path ([IO.Path]::GetTempPath()) ('USBAnywhereWorkerTest-'+[Guid]::NewGuid().ToString('N'))
$process=$null
$processStarted=$false
try {
    New-Item -ItemType Directory -Path $root | Out-Null
    foreach ($name in @('reconnect-client.ps1','client-discovery.ps1')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $root $name)
    }
    $client=Join-Path $root 'fake-usbip.exe'
    $source=@'
using System;
using System.IO;
namespace NAMESPACE {
    public static class FakeClient {
        private static string Root { get { return AppDomain.CurrentDomain.BaseDirectory; } }
        private static int Increment(string name) {
            string path=Path.Combine(Root,name);
            int value=File.Exists(path) ? Int32.Parse(File.ReadAllText(path)) : 0;
            File.WriteAllText(path,(++value).ToString());
            return value;
        }
        public static int Main(string[] args) {
            File.AppendAllText(Path.Combine(Root,"calls.txt"),String.Join(" ",args)+Environment.NewLine);
            if (args.Length==3 && args[0]=="list" && args[1]=="-r" && args[2]=="127.0.0.7") {
                int scan=Increment("scans.txt");
                Console.WriteLine("Exportable USB devices");
                Console.WriteLine("======================");
                if (scan>1) Console.WriteLine("    1-5 : Temporary test device (1234:5678)");
                return 0;
            }
            if (args.Length==1 && args[0]=="port") {
                string path=Path.Combine(Root,"attachments.txt");
                int attempts=File.Exists(path) ? Int32.Parse(File.ReadAllText(path)) : 0;
                if (attempts>=2) Console.WriteLine("    -> usbip://127.0.0.7:3240/1-5");
                return 0;
            }
            if (String.Join(" ",args)=="attach -r 127.0.0.7 -b 1-5 --receive-mode=zero-copy --once") {
                return Increment("attachments.txt")==1 ? 1 : 0;
            }
            Console.Error.WriteLine("Unexpected fake-client arguments: "+String.Join(" ",args));
            return 99;
        }
    }
}
'@
    $source=$source.Replace('NAMESPACE','WorkerTest'+[Guid]::NewGuid().ToString('N'))
    Add-Type -TypeDefinition $source -Language CSharp -OutputAssembly $client -OutputType ConsoleApplication
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $worker=Join-Path $root 'reconnect-client.ps1'
    $start.Arguments="-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$worker`" -Server 127.0.0.7 -ReceiveMode zero-copy -BusIDs auto -TestIterations 4 -TestClientPath `"$client`""
    $start.WorkingDirectory=$root
    $start.UseShellExecute=$false; $start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
    $process=[Diagnostics.Process]::new(); $process.StartInfo=$start
    [void]$process.Start()
    $processStarted=$true
    $stdout=$process.StandardOutput.ReadToEndAsync(); $stderr=$process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(25000)) {
        $process.Kill(); [void]$process.WaitForExit(2000)
        throw 'Bounded reconnect worker did not exit within 25 seconds'
    }
    $output=$stdout.Result
    if ($process.ExitCode -ne 0) { throw ('Reconnect worker failed: '+$stderr.Result) }
    $calls=@(Get-Content -LiteralPath (Join-Path $root 'calls.txt'))
    $attach='attach -r 127.0.0.7 -b 1-5 --receive-mode=zero-copy --once'
    $expected=@('list -r 127.0.0.7','list -r 127.0.0.7','port',$attach,'list -r 127.0.0.7','port',$attach,'list -r 127.0.0.7','port')
    if (($calls -join "`n") -cne ($expected -join "`n")) { throw ('Unexpected worker command sequence: '+($calls -join '; ')) }
    if ($output -notmatch '1-5 waiting for server/device' -or $output -notmatch '1-5 connected \(zero-copy\)') {
        throw ('Missing failed-attach/retry-success state transitions: '+$output)
    }
    'PASS: real bounded worker accepts empty exports, adopts a new bus ID, retries failed attach, preserves receive mode and recognizes an existing attachment'
} finally {
    if ($process) {
        if ($processStarted -and -not $process.HasExited) { $process.Kill(); [void]$process.WaitForExit(2000) }
        $process.Dispose()
    }
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
