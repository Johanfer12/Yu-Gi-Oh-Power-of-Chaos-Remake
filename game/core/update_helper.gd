extends RefCounted
## Static helper, separate process because Windows locks a running executable.
const SCRIPT := """
$ErrorActionPreference = 'Stop'
# Avoid inheriting PowerShell 7 module paths in the Windows PowerShell helper.
$env:PSModulePath = Join-Path $PSHOME 'Modules'
function FileDigest([string]$path) {
    $stream = [IO.File]::OpenRead($path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
    finally { $stream.Dispose(); $sha.Dispose() }
}
$settingsPath = Join-Path $PSScriptRoot 'update.json'
$logPath = Join-Path $PSScriptRoot 'last-update.log'
$backup = $null
$moved = $false
$installed = $false
$c = $null
$source = $null
try {
    $c = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $target = [IO.Path]::GetFullPath($c.target)
    $source = [IO.Path]::GetFullPath($c.source)
    if ($source -ne (Join-Path $PSScriptRoot 'PowerOfChaos.download')) { throw 'Unexpected download path' }
    if ($target -eq $source -or [IO.Path]::GetExtension($target) -ne '.exe') { throw 'Invalid target' }
    if ((FileDigest $source) -ne $c.sha256) { throw 'SHA-256 mismatch' }
    $process = Get-Process -Id $c.pid -ErrorAction SilentlyContinue
    if ($process -and -not $process.WaitForExit(60000)) { throw 'Launcher is still running' }
    $backup = $target + '.update-backup'
    if (Test-Path -LiteralPath $backup) { throw 'An earlier backup needs recovery' }
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        try { Move-Item -LiteralPath $target -Destination $backup; $moved = $true; break }
        catch { if ($attempt -eq 39) { throw }; Start-Sleep -Milliseconds 250 }
    }
    Copy-Item -LiteralPath $source -Destination $target
    if ((FileDigest $target) -ne $c.sha256) { throw 'Installed SHA-256 mismatch' }
    Start-Process -FilePath $target -WorkingDirectory ([IO.Path]::GetDirectoryName($target))
    $installed = $true
    'Update installed successfully' | Set-Content -LiteralPath $logPath -Encoding UTF8
} catch {
    $failure = $_.Exception.Message
    if ($moved -and -not $installed) {
        try {
            if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target }
            Move-Item -LiteralPath $backup -Destination $target
            Start-Process -FilePath $target -WorkingDirectory ([IO.Path]::GetDirectoryName($target))
        } catch { $failure += '; rollback: ' + $_.Exception.Message }
    }
    $failure | Set-Content -LiteralPath $logPath -Encoding UTF8
} finally {
    if ($installed -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -ErrorAction SilentlyContinue }
    if ($source -and $source -eq (Join-Path $PSScriptRoot 'PowerOfChaos.download') -and (Test-Path -LiteralPath $source)) {
        Remove-Item -LiteralPath $source -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $settingsPath -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $PSCommandPath -ErrorAction SilentlyContinue
}
"""
