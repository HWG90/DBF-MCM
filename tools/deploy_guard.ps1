$ErrorActionPreference = 'Stop'
function Assert-UnvirtualizedPath([string]$Path) {
    $normalized=$Path.Replace('\','/').ToLowerInvariant()
    if($normalized -match '/windowsapps/|/localcache/|pythonsoftwarefoundation\.python') {
        throw "Rejected Store/virtualized path: $Path"
    }
}
function Assert-IntendedTarget([string]$Path,[string]$Root) {
    Assert-UnvirtualizedPath $Path
    $absolute=[IO.Path]::GetFullPath($Path)
    $boundary=[IO.Path]::GetFullPath($Root).TrimEnd('\')+'\'
    if(-not $absolute.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase)) {throw "Target leaves intended installed root: $absolute"}
    return $absolute
}
function Assert-HashEquals([string]$Actual,[string]$Expected) {
    if($Actual -ne $Expected) {throw "Installed SHA-256 mismatch; stopped. Expected $Expected, actual $Actual. Use the preserved rollback; do not blindly redeploy."}
}
function Get-PhysicalFilePath([string]$Path) {
    if(-not ('EpicLutPhysicalFile' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class EpicLutPhysicalFile {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]
 public static extern uint GetFinalPathNameByHandleW(SafeFileHandle handle,StringBuilder path,uint size,uint flags);
}
'@
    }
    $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
    try {
        $buffer=[Text.StringBuilder]::new(32768)
        $length=[EpicLutPhysicalFile]::GetFinalPathNameByHandleW($stream.SafeFileHandle,$buffer,32768,0)
        if($length -eq 0 -or $length -ge 32768) {throw 'Final installed-file path unavailable'}
        $physical=$buffer.ToString()
        if($physical.StartsWith('\\?\')) {$physical=$physical.Substring(4)}
        Assert-UnvirtualizedPath $physical
        return $physical
    } finally {$stream.Dispose()}
}
function Assert-PhysicalDestination([string]$Path) {
    $physical=Get-PhysicalFilePath $Path
    $intended=[IO.Path]::GetFullPath($Path)
    if(-not $physical.Equals($intended,[StringComparison]::OrdinalIgnoreCase)) {throw "Installed path was redirected: intended $intended, physical $physical"}
}
function Invoke-GuardedModuleDeployment {
    param([string]$Candidate,[string]$TargetDirectory,[string]$InstalledRoot,[string]$BackupRoot,[string]$ReloadLog,[string]$ReloadMarker,[int]$VerifyDelaySeconds=5)
    Assert-UnvirtualizedPath $Candidate
    $candidatePath=(Resolve-Path -LiteralPath $Candidate).Path
    $target=Assert-IntendedTarget (Join-Path $TargetDirectory 'mod.lua') $InstalledRoot
    if(-not (Test-Path -LiteralPath $target)) {throw 'Existing installed module required; first installation needs a separately reviewed package deployment'}
    Assert-PhysicalDestination $target
    $expected=(Get-FileHash -LiteralPath $candidatePath -Algorithm SHA256).Hash
    $before=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    if($before -eq $expected) {
        Start-Sleep -Seconds $VerifyDelaySeconds
        Assert-PhysicalDestination $target
        Assert-HashEquals (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash $expected
        Write-Output "Already installed; physical destination and stable SHA-256 verified: $expected"
        return
    }
    $oldLog=Get-Content -LiteralPath $ReloadLog -Raw
    $backup=Join-Path $BackupRoot ((Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    Copy-Item -LiteralPath $target -Destination (Join-Path $backup 'mod.lua')
    Assert-HashEquals (Get-FileHash -LiteralPath (Join-Path $backup 'mod.lua')).Hash $before
    Assert-HashEquals (Get-FileHash -LiteralPath $target).Hash $before
    $staging=$target+'.reviewed-'+[Guid]::NewGuid().ToString('N')+'.tmp'
    Copy-Item -LiteralPath $candidatePath -Destination $staging
    Assert-HashEquals (Get-FileHash -LiteralPath $staging).Hash $expected
    Move-Item -LiteralPath $staging -Destination $target -Force
    Assert-PhysicalDestination $target
    Assert-HashEquals (Get-FileHash -LiteralPath $target).Hash $expected
    Start-Sleep -Seconds $VerifyDelaySeconds
    Assert-PhysicalDestination $target
    Assert-HashEquals (Get-FileHash -LiteralPath $target).Hash $expected
    $newLog=Get-Content -LiteralPath $ReloadLog -Raw
    if($newLog.Length -lt $oldLog.Length) {throw "Log rotated; reload unverified. Backup: $backup"}
    $added=$newLog.Substring($oldLog.Length)
    if($added -notmatch [regex]::Escape($ReloadMarker)) {throw "Installed hash verified, but successful reload not confirmed. Backup: $backup"}
    @{candidate=$candidatePath;target=$target;physical_target=(Get-PhysicalFilePath $target);before_sha256=$before;after_sha256=$expected;rollback=$backup;reload_confirmed=$true} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $backup 'receipt.json') -Encoding utf8
    Write-Output "Installed and reload verified: $expected. Rollback: $backup"
}
