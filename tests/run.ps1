param([switch]$SkipBuild,[switch]$Mixed,[switch]$Installed,[string]$ResumeTestId='')
$ErrorActionPreference = 'Stop'
$modRoot = Split-Path $PSScriptRoot -Parent
$gameRoot = Split-Path (Split-Path $modRoot -Parent) -Parent
if (!$SkipBuild -and !$Installed) { & (Join-Path $modRoot 'build\build.ps1') -Tests }
$modSource = Join-Path $modRoot $(if($Installed){'release\LightAndDarknessMod.swf'}else{'build\out\LightAndDarknessMod.swf'})
$modSourceHash = (Get-FileHash -LiteralPath $modSource).Hash
$modRow = 'LightAndDarkness|LightAndDarknessMod|1|0|0'
if ($Installed) {
    $rows = @(Get-Content -LiteralPath (Join-Path $gameRoot 'mods\loader-manifest.txt') | Where-Object { $_ -match '^LightAndDarkness\|' })
    if ($rows.Count -ne 1 -or $rows[0] -cne $modRow) { throw 'Installed manifest must contain exactly the validated 1.02 entry' }
    $modRow = $rows[0]
}
$runtimeRoot = Join-Path $modRoot 'build\runtime'
$testId = 'remains-lad-test-' + (Get-Date -Format 'yyyyMMddHHmmssfff')
$evidence = Join-Path $modRoot "build\evidence\$testId"
if ($ResumeTestId) {
    if ($ResumeTestId -notmatch '^remains-lad-test-\d{17}$') { throw 'Only a generated LightAndDarkness test identity may be resumed' }
    if (!(Test-Path -LiteralPath (Join-Path $env:APPDATA "$ResumeTestId\Local Store"))) { throw 'Missing prior test storage' }
    $testId = $ResumeTestId
    $evidence = Join-Path $modRoot ('build\evidence\' + $testId + '-cold-' + (Get-Date -Format 'HHmmss'))
}
New-Item -ItemType Directory -Force -Path $runtimeRoot, $evidence | Out-Null
$assets = @('pfe.swf','texture.swf','texture1.swf','sprite.swf','sprite1.swf','sound.swf','sound_unit.swf','sound_weapon.swf','lang.xml','rooms.xml')
$assets += (Get-ChildItem -LiteralPath $gameRoot -Filter 'text_*.xml').Name
foreach ($asset in $assets) {
    $source = Join-Path $gameRoot $asset
    $target = Join-Path $runtimeRoot $asset
    if (!(Test-Path -LiteralPath $target) -or (Get-Item -LiteralPath $source).LastWriteTimeUtc -ne (Get-Item -LiteralPath $target).LastWriteTimeUtc) { Copy-Item -LiteralPath $source -Destination $target -Force }
}
if (!(Test-Path -LiteralPath (Join-Path $runtimeRoot 'Rooms'))) { Copy-Item -LiteralPath (Join-Path $gameRoot 'Rooms') -Destination $runtimeRoot -Recurse }
$release = Join-Path $runtimeRoot 'mods\LightAndDarkness\release'
New-Item -ItemType Directory -Force -Path $release | Out-Null
Copy-Item -LiteralPath $modSource, (Join-Path $modRoot 'build\out\LightAndDarknessTest.swf') -Destination $release -Force
if ((Get-FileHash -LiteralPath (Join-Path $release 'LightAndDarknessMod.swf')).Hash -ne $modSourceHash) { throw 'Test copy differs from source' }
@("Source: $modSource", "SHA256: $modSourceHash", "Manifest row: $modRow") | Set-Content -LiteralPath (Join-Path $evidence 'source.txt') -Encoding utf8
$manifest = "$modRow`nLightAndDarkness|LightAndDarknessTest|1|0|0`n"
if ($Mixed) {
    foreach ($name in @('ContinuousScene','RealisticVision','WallBlend','ModLoader')) {
        $sourceRelease = Join-Path $gameRoot "mods\$name\release"
        $testRelease = Join-Path $runtimeRoot "mods\$name\release"
        New-Item -ItemType Directory -Force -Path $testRelease | Out-Null
        Get-ChildItem -LiteralPath $sourceRelease -File | Where-Object Extension -In '.swf','.xml','.txt','.json' | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $testRelease -Force }
        $manifest += "$name|${name}Mod|1|0|0`n"
    }
}
[IO.File]::WriteAllText((Join-Path $runtimeRoot 'test-mode.txt'),$(if($ResumeTestId){'cold'}elseif($Mixed){'mixed'}else{'single'}),[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $runtimeRoot 'mods\loader-manifest.txt'), $manifest, [Text.UTF8Encoding]::new($false))
$descriptor = Join-Path $runtimeRoot 'app_lad_test.xml'
$xml = "<?xml version=`"1.0`" encoding=`"utf-8`"?><application xmlns=`"http://ns.adobe.com/air/application/30.0`"><id>$testId</id><versionNumber>1.0</versionNumber><filename>LightAndDarknessTest</filename><initialWindow><content>pfe.swf</content><visible>false</visible><width>1100</width><height>700</height><renderMode>direct</renderMode></initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>"
[IO.File]::WriteAllText($descriptor,$xml,[Text.UTF8Encoding]::new($false))
$storage = Join-Path $env:APPDATA "$testId\Local Store"
if ($ResumeTestId) {
    foreach ($oldLog in @('test.log','LightAndDarkness.log')) {
        $logPath = Join-Path $storage $oldLog
        if (Test-Path -LiteralPath $logPath) { Copy-Item -LiteralPath $logPath -Destination (Join-Path $evidence ('previous-'+$oldLog)); Remove-Item -LiteralPath $logPath }
    }
}
$process = $null
try {
    $args = '-runtime "' + (Join-Path $gameRoot 'runtimes\air\win64') + '" "' + $descriptor + '" -nodebug'
    $process = Start-Process -FilePath (Join-Path $gameRoot 'adl64.exe') -ArgumentList $args -WorkingDirectory $runtimeRoot -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(200)
    $activeLog = Join-Path $storage 'test.log'
    while (!$process.HasExited -and [DateTime]::UtcNow -lt $deadline) {
        if ((Test-Path -LiteralPath $activeLog) -and (Select-String -LiteralPath $activeLog -Pattern 'SUITE_PASS| FAIL ' -Quiet)) { break }
        Start-Sleep -Milliseconds 500
    }
    if ([DateTime]::UtcNow -ge $deadline) { throw "Test timeout. Process $($process.Id)" }
} finally {
    if ($process -and !$process.HasExited) { Stop-Process -Id $process.Id -Force }
    if (Test-Path -LiteralPath $storage) { Copy-Item -LiteralPath $storage -Destination (Join-Path $evidence 'storage') -Recurse }
    Get-FileHash -LiteralPath (Join-Path $runtimeRoot 'pfe.swf'),(Join-Path $release 'LightAndDarknessMod.swf') | Format-List | Out-File (Join-Path $evidence 'hashes.txt')
    if (Test-Path -LiteralPath $descriptor) { Remove-Item -LiteralPath $descriptor }
}
Write-Output "Evidence: $evidence"
$log = Join-Path $evidence 'storage\test.log'
if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log }
else { throw "No test log at $log" }
if (!(Select-String -LiteralPath $log -Pattern 'SUITE_PASS' -Quiet) -or (Select-String -LiteralPath $log -Pattern 'FAIL' -Quiet)) { throw 'Test did not pass' }
