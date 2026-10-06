param([string]$Candidate=(Join-Path $PSScriptRoot 'dist\dbf_mcm\mod.lua'))
$ErrorActionPreference='Stop'
. "$PSScriptRoot\tools\deploy_guard.ps1"
Assert-UnvirtualizedPath $Candidate
$installedRoot=Join-Path $env:LOCALAPPDATA 'LLL\Helldivers2\Mods'
$target=Join-Path $installedRoot 'dbf_mcm'
$text=Get-Content -LiteralPath $Candidate -Raw
if($text -notmatch 'window_resize' -or $text -notmatch 'local function group_name') {throw 'Candidate lacks the protected resize or numeric legacy-group implementation; refused'}
$library=(Get-Content -LiteralPath (Join-Path $target 'library.txt') -Raw).Trim()
if(-not (Test-Path -LiteralPath (Join-Path $target $library))) {throw 'Existing native library missing; native-input changes require separate review'}
# Only the Lua module is replaced. This entrypoint never installs a native input DLL.
Invoke-GuardedModuleDeployment -Candidate $Candidate -TargetDirectory $target -InstalledRoot $installedRoot -BackupRoot "$PSScriptRoot\dist\deployment-backups" -ReloadLog (Join-Path $env:LOCALAPPDATA 'LLL\Helldivers2\Logs\LiveLuaLoader.log') -ReloadMarker 'live/dbf_mcm: loaded'
