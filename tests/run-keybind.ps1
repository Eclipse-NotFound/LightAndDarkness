param([Parameter(Mandatory=$true)][string]$GameRoot,[string]$ResumeTestId='',[string]$SharedHostCandidate='',[string]$CandidateDirectory='',[string]$HostCandidate='')
$ErrorActionPreference='Stop'
$GameRoot=(Resolve-Path -LiteralPath $GameRoot).Path
$modRoot=Split-Path $PSScriptRoot -Parent
if (!$CandidateDirectory) {$CandidateDirectory=Join-Path $modRoot 'build/out'}
$CandidateDirectory=(Resolve-Path -LiteralPath $CandidateDirectory).Path
$runtime=Join-Path $modRoot 'build/keybind-runtime'
$testId='remains-lad-keybind-'+(Get-Date -Format 'yyyyMMddHHmmssfff')
if ($ResumeTestId) {
    if ($ResumeTestId -notmatch '^remains-lad-keybind-\d{17}$') {throw 'Only this probe identity may be resumed'}
    $testId=$ResumeTestId
    if (!(Test-Path -LiteralPath (Join-Path $env:APPDATA "$testId/Local Store/LightAndDarkness.keys.json"))) {throw 'Missing prior key settings'}
}
$evidence=Join-Path $modRoot ('build/evidence/'+$testId+$(if($ResumeTestId){'-cold-'+(Get-Date -Format 'HHmmss')}else{''}))
New-Item -ItemType Directory -Force -Path $runtime,$evidence | Out-Null
$assets=@('pfe.swf','texture.swf','texture1.swf','sprite.swf','sprite1.swf','sound.swf','sound_unit.swf','sound_weapon.swf','lang.xml','rooms.xml')
$assets+=(Get-ChildItem -LiteralPath $GameRoot -Filter 'text_*.xml').Name
foreach ($asset in $assets) {
    $source=Join-Path $GameRoot $asset;$target=Join-Path $runtime $asset
    if($asset -eq 'pfe.swf' -and $HostCandidate) {$source=(Resolve-Path -LiteralPath $HostCandidate).Path}
    if (!(Test-Path -LiteralPath $target) -or (Get-Item -LiteralPath $source).LastWriteTimeUtc -ne (Get-Item -LiteralPath $target).LastWriteTimeUtc) {Copy-Item -LiteralPath $source -Destination $target -Force}
}
if (!(Test-Path -LiteralPath (Join-Path $runtime 'Rooms'))) {Copy-Item -LiteralPath (Join-Path $GameRoot 'Rooms') -Destination $runtime -Recurse}
$release=Join-Path $runtime 'mods/LightAndDarkness/release'
New-Item -ItemType Directory -Force -Path $release | Out-Null
Copy-Item -LiteralPath (Join-Path $CandidateDirectory 'LightAndDarknessMod.swf'),(Join-Path $CandidateDirectory 'KeybindProbe.swf') -Destination $release -Force
Copy-Item -LiteralPath (Join-Path $modRoot 'atmosphere.json') -Destination (Join-Path (Split-Path $release -Parent) 'atmosphere.json') -Force
$manifest="LightAndDarkness|LightAndDarknessMod|1|0|0`nLightAndDarkness|KeybindProbe|1|0|0`n"
if ($SharedHostCandidate) {
    $hostRelease=Join-Path $runtime 'mods/ModLoader/release'
    New-Item -ItemType Directory -Force -Path $hostRelease | Out-Null
    Copy-Item -LiteralPath $SharedHostCandidate -Destination (Join-Path $hostRelease 'ModLoaderMod.swf') -Force
    Get-ChildItem -LiteralPath (Join-Path $GameRoot 'mods/ModLoader/release') -File | Where-Object Extension -In '.txt','.xml','.json' | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination $hostRelease -Force}
    $manifest+="ModLoader|ModLoaderMod|1|0|0`n"
    Get-FileHash -LiteralPath (Join-Path $hostRelease 'ModLoaderMod.swf') | Format-List | Out-File (Join-Path $evidence 'shared-host-hash.txt')
}
[IO.File]::WriteAllText((Join-Path $runtime 'mods/loader-manifest.txt'),$manifest,[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $runtime 'keybind-mode.txt'),$(if($ResumeTestId){'cold'}elseif($SharedHostCandidate){'shared'}else{'full'}),[Text.UTF8Encoding]::new($false))
$descriptor=Join-Path $runtime 'app_lad_keybind_test.xml'
$xml="<?xml version='1.0' encoding='utf-8'?><application xmlns='http://ns.adobe.com/air/application/30.0'><id>$testId</id><versionNumber>1.0</versionNumber><filename>LightKeybindTest</filename><initialWindow><content>pfe.swf</content><visible>false</visible><width>1100</width><height>700</height><renderMode>direct</renderMode></initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>"
[IO.File]::WriteAllText($descriptor,$xml,[Text.UTF8Encoding]::new($false))
$storage=Join-Path $env:APPDATA "$testId/Local Store"
if ($ResumeTestId) {
    foreach ($name in @('keybind-test.log','LightAndDarkness.log')) {
        $old=Join-Path $storage $name
        if (Test-Path -LiteralPath $old) {Copy-Item -LiteralPath $old -Destination (Join-Path $evidence ('previous-'+$name));Remove-Item -LiteralPath $old}
    }
}
$process=$null
try {
    $arguments='-runtime "'+(Join-Path $GameRoot 'runtimes/air/win64')+'" "'+$descriptor+'" -nodebug'
    $process=Start-Process -FilePath (Join-Path $GameRoot 'adl64.exe') -ArgumentList $arguments -WorkingDirectory $runtime -WindowStyle Hidden -PassThru
    if($HostCandidate) {
        . (Join-Path $GameRoot 'mods/ContinuousScene/build/test-process.ps1')
        [ContinuousSceneTest.Power]::Responsive($process) | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'process-policy.json')
    }
    $deadline=[DateTime]::UtcNow.AddSeconds(190);$log=Join-Path $storage 'keybind-test.log'
    while (!$process.HasExited -and [DateTime]::UtcNow -lt $deadline) {
        if ((Test-Path -LiteralPath $log) -and (Select-String -LiteralPath $log -Pattern '^\d+ (SUITE_PASS$|FAIL )' -Quiet)) {break}
        Start-Sleep -Milliseconds 500
    }
    if ([DateTime]::UtcNow -ge $deadline) {throw 'Keybind probe timeout'}
} finally {
    if ($process -and !$process.HasExited) {Stop-Process -Id $process.Id -Force}
    if (Test-Path -LiteralPath $storage) {Copy-Item -LiteralPath $storage -Destination (Join-Path $evidence 'storage') -Recurse}
    Get-FileHash -LiteralPath (Join-Path $runtime 'pfe.swf'),(Join-Path $release 'LightAndDarknessMod.swf') | Format-List | Out-File (Join-Path $evidence 'hashes.txt')
    $tested=@((Join-Path $runtime 'pfe.swf'),(Join-Path $release 'LightAndDarknessMod.swf'),(Join-Path $release 'KeybindProbe.swf'))
    if($SharedHostCandidate) {$tested+=Join-Path $runtime 'mods/ModLoader/release/ModLoaderMod.swf'}
    Get-FileHash -LiteralPath $tested | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'candidate-hashes.json')
    if (Test-Path -LiteralPath $descriptor) {Remove-Item -LiteralPath $descriptor}
}
Write-Output ("Evidence: "+$evidence)
$result=Join-Path $evidence 'storage/keybind-test.log'
if (!(Test-Path -LiteralPath $result)) {throw 'No keybind test log'}
Get-Content -LiteralPath $result
if (!(Select-String -LiteralPath $result -Pattern '^\d+ SUITE_PASS$' -Quiet) -or (Select-String -LiteralPath $result -Pattern '^\d+ FAIL ' -Quiet)) {throw 'Keybind tests failed'}
