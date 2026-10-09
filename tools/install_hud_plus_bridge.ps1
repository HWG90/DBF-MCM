param(
    [Parameter(Mandatory=$true)][string]$PackageDirectory,
    [Parameter(Mandatory=$true)][string]$CandidateZip,
    [string]$GameData='C:\Program Files (x86)\Steam\steamapps\common\Helldivers 2\data'
)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\deploy_guard.ps1"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$originalHash='5DA7897D174F5B39337DF3195FE3A70D8C48D42F47903FBB83C8EC2560BF2B99'
$archiveName='9ba626afa44a3aa3.patch_0'
function Assert-GameClosed {
    if(Get-Process helldivers2 -ErrorAction SilentlyContinue) {throw 'Close Helldivers 2 before installing the HUD+ owner bridge.'}
}
Assert-GameClosed
$candidate=(Resolve-Path -LiteralPath $CandidateZip).Path
Assert-IntendedTarget $candidate (Join-Path $repo 'dist') | Out-Null
$report=Get-Content -LiteralPath ([IO.Path]::ChangeExtension($candidate,'.verification.json')) -Raw | ConvertFrom-Json
if($report.original_archive_sha256 -ne $originalHash -or -not $report.syntax_verified -or -not $report.third_party_review_only) {throw 'Candidate lacks the verified local HUD+ patch receipt.'}
Assert-HashEquals (Get-FileHash -LiteralPath $candidate).Hash $report.review_zip_sha256.ToUpperInvariant()
$source=(Resolve-Path -LiteralPath (Join-Path $PackageDirectory $archiveName)).Path
Assert-PhysicalDestination $source
Assert-HashEquals (Get-FileHash -LiteralPath $source).Hash $originalHash
$gameRoot=(Resolve-Path -LiteralPath $GameData).Path
$sourceSize=(Get-Item -LiteralPath $source).Length
$matches=@(Get-ChildItem -LiteralPath $gameRoot -File -Filter '9ba626afa44a3aa3.patch_*' |
    Where-Object {$_.Name -match '^9ba626afa44a3aa3\.patch_\d+$' -and $_.Length -eq $sourceSize} |
    Where-Object {(Get-FileHash -LiteralPath $_.FullName).Hash -eq $originalHash})
if($matches.Count -ne 1) {throw 'Exactly one deployed original HUD+ archive is required; no files were changed.'}
$deployed=Assert-IntendedTarget $matches[0].FullName $gameRoot
Assert-PhysicalDestination $deployed
$zip=[IO.Compression.ZipFile]::OpenRead($candidate)
try {
    $entries=@($zip.Entries | Where-Object {$_.FullName -eq $archiveName})
    if($entries.Count -ne 1 -or $entries[0].Length -gt 2097152) {throw 'Invalid HUD+ candidate archive entry.'}
    $stream=$entries[0].Open();$buffer=[IO.MemoryStream]::new()
    try {$stream.CopyTo($buffer);$bytes=$buffer.ToArray()} finally {$stream.Dispose();$buffer.Dispose()}
} finally {$zip.Dispose()}
$hasher=[Security.Cryptography.SHA256]::Create()
try {$after=([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-','')} finally {$hasher.Dispose()}
Assert-HashEquals $after $report.patched_archive_sha256.ToUpperInvariant()
$backup=Join-Path $repo ('dist\deployment-backups\hud-plus-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $backup | Out-Null
$records=@(
    @{target=$source;backup=(Join-Path $backup 'arsenal-original.patch_0')},
    @{target=$deployed;backup=(Join-Path $backup 'game-original.patch_0')}
)
foreach($record in $records) {
    Copy-Item -LiteralPath $record.target -Destination $record.backup
    Assert-HashEquals (Get-FileHash -LiteralPath $record.backup).Hash $originalHash
}
$written=@()
try {
    foreach($record in $records) {
        Assert-GameClosed
        Assert-PhysicalDestination $record.target
        Assert-HashEquals (Get-FileHash -LiteralPath $record.target).Hash $originalHash
        $temporary=$record.target+'.mcm-'+[Guid]::NewGuid().ToString('N')+'.tmp'
        try {
            [IO.File]::WriteAllBytes($temporary,$bytes)
            Assert-HashEquals (Get-FileHash -LiteralPath $temporary).Hash $after
            Assert-GameClosed
            Move-Item -LiteralPath $temporary -Destination $record.target -Force
            $written+=,$record
            Assert-PhysicalDestination $record.target
            Assert-HashEquals (Get-FileHash -LiteralPath $record.target).Hash $after
        } finally {if(Test-Path -LiteralPath $temporary) {Remove-Item -LiteralPath $temporary}}
    }
} catch {
    foreach($record in $written) {
        Assert-GameClosed
        Copy-Item -LiteralPath $record.backup -Destination $record.target -Force
        Assert-HashEquals (Get-FileHash -LiteralPath $record.target).Hash $originalHash
    }
    throw
}
$receipt=@{version='0.2.2';before_sha256=$originalHash;after_sha256=$after;candidate=$candidate;files=$records;game_running=$false;live_verified=$false;settings_modified=$false}
$receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $backup 'receipt.json') -Encoding utf8
Write-Output "Installed HUD+ owner bridge into the existing Arsenal package and deployed archive. Settings preserved. Next game launch required. Rollback: $backup"
