param([string]$Python=(Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'))
$ErrorActionPreference='Stop'
. "$PSScriptRoot\tools\deploy_guard.ps1"
Assert-UnvirtualizedPath $Python
Assert-UnvirtualizedPath (Get-PhysicalFilePath $Python)
Push-Location $PSScriptRoot
try {& $Python build.py;if($LASTEXITCODE -ne 0) {throw 'MCM build failed'}} finally {Pop-Location}
