$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\deploy_guard.ps1"
function Reject([scriptblock]$Action) {try {& $Action}catch{return};throw 'Unsafe deployment was accepted'}
Reject {Assert-UnvirtualizedPath 'C:\WindowsApps\python.exe'}
Reject {Assert-UnvirtualizedPath 'C:\Users\test\AppData\Local\Packages\PythonSoftwareFoundation.Python\LocalCache\Local\MDL\mod.lua'}
Reject {Assert-IntendedTarget 'C:\wrong\mod.lua' 'C:\intended\Mods'}
Reject {Assert-HashEquals ('A'*64) ('B'*64)}
$file=Join-Path $env:TEMP ('mcm-deploy-guard-'+[Guid]::NewGuid().ToString('N')+'.lua')
try {
    Set-Content -LiteralPath $file -Value 'return {}' -Encoding utf8
    Reject {& "$PSScriptRoot\..\deploy.ps1" -Candidate $file}
} finally {Remove-Item -LiteralPath $file -ErrorAction SilentlyContinue}
Write-Output 'PASS: MCM Store/LocalCache rejection, target containment, hash mismatch stop, missing resize/legacy protection'
