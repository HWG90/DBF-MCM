param([Parameter(Mandatory=$true)][string]$OriginalPackage,[Parameter(Mandatory=$true)][string]$CandidateZip)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$original=Join-Path $OriginalPackage '9ba626afa44a3aa3.patch_0'
$fixture=Join-Path $repo ('dist\hud-plus-installer-fixture-'+[Guid]::NewGuid().ToString('N'))
$package=Join-Path $fixture 'package';$game=Join-Path $fixture 'data'
New-Item -ItemType Directory -Path $package,$game | Out-Null
$source=Join-Path $package '9ba626afa44a3aa3.patch_0'
$deployed=Join-Path $game '9ba626afa44a3aa3.patch_59'
Copy-Item -LiteralPath $original -Destination $source
Copy-Item -LiteralPath $original -Destination $deployed
$before=(Get-FileHash -LiteralPath $original).Hash
$report=Get-Content -LiteralPath ([IO.Path]::ChangeExtension([IO.Path]::GetFullPath($CandidateZip),'.verification.json')) -Raw | ConvertFrom-Json
& "$repo\tools\install_hud_plus_bridge.ps1" -PackageDirectory $package -GameData $game -CandidateZip $CandidateZip
if((Get-FileHash -LiteralPath $source).Hash -ne $report.patched_archive_sha256 -or (Get-FileHash -LiteralPath $deployed).Hash -ne $report.patched_archive_sha256) {throw 'Fixture installation hash mismatch'}
if((Get-FileHash -LiteralPath $original).Hash -ne $before) {throw 'Fixture test changed original package'}
# Already changed/unknown packages must be refused before replacing the game copy.
$refused=$false
try {& "$repo\tools\install_hud_plus_bridge.ps1" -PackageDirectory $package -GameData $game -CandidateZip $CandidateZip} catch {$refused=$true}
if(-not $refused -or (Get-FileHash -LiteralPath $deployed).Hash -ne $report.patched_archive_sha256) {throw 'Unknown/already-patched fixture was not safely refused'}
Write-Output "PASS real installer with isolated file fixtures; both archives match, original source retained, reinstallation refused. Fixture: $fixture"
