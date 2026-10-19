param([switch]$Mixed,[string]$Candidate='',[string]$Mode='atlas',[int]$Timeout=240,[string]$ExpectedVersion='0.3.2',[string]$ProbePath='',
 [string]$Python='C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe')
$ErrorActionPreference='Stop'
$ladRoot=Split-Path $PSScriptRoot -Parent
$ladGame=Split-Path (Split-Path $ladRoot -Parent) -Parent
$ladId='remains-lad-machine-'+(Get-Date -Format 'yyyyMMddHHmmssfff')
$ladRuntime=Join-Path $ladRoot ('build/generated/'+$ladId)
$ladEvidence=Join-Path $ladRoot ('build/evidence/'+$ladId)
New-Item -ItemType Directory -Force -Path $ladRuntime,$ladEvidence | Out-Null
$ladAssets=@('pfe.swf','texture.swf','texture1.swf','sprite.swf','sprite1.swf','sound.swf','sound_unit.swf','sound_weapon.swf','lang.xml','rooms.xml')
$ladAssets+=(Get-ChildItem -LiteralPath $ladGame -Filter 'text_*.xml').Name
foreach($ladAsset in $ladAssets){Copy-Item -LiteralPath (Join-Path $ladGame $ladAsset) -Destination $ladRuntime -Force}
if(!(Test-Path -LiteralPath (Join-Path $ladRuntime 'Rooms'))){Copy-Item -LiteralPath (Join-Path $ladGame 'Rooms') -Destination $ladRuntime -Recurse}
$ladRelease=Join-Path $ladRuntime 'mods/LightAndDarkness/release'
New-Item -ItemType Directory -Force -Path $ladRelease | Out-Null
if(!$Candidate){$Candidate=Join-Path $ladRoot 'release/LightAndDarknessMod.swf'}
Copy-Item -LiteralPath $Candidate -Destination (Join-Path $ladRelease 'LightAndDarknessMod.swf') -Force
if(!$ProbePath){$ProbePath=Join-Path $ladRoot 'build/out/machines-v032/LightMachineProbeMod.swf'}
Copy-Item -LiteralPath $ProbePath -Destination $ladRelease -Force
Copy-Item -LiteralPath (Join-Path $ladRoot 'atmosphere.json') -Destination (Join-Path (Split-Path $ladRelease -Parent) 'atmosphere.json') -Force
$ladEntries=@('LightAndDarknessMod','LightMachineProbeMod')
$ladHashes=@((Join-Path $ladRuntime 'pfe.swf'),(Join-Path $ladRelease 'LightAndDarknessMod.swf'),(Join-Path $ladRelease 'LightMachineProbeMod.swf'))
$ladLoader=Join-Path $ladRuntime 'mods/ModLoader'
New-Item -ItemType Directory -Force -Path $ladLoader | Out-Null
Copy-Item -LiteralPath (Join-Path $ladGame 'mods/ModLoader/supported-mods.txt') -Destination $ladLoader -Force
if($Mixed){foreach($ladMod in @('ModLoader','ContinuousScene','RealisticVision','WallBlend')){
 $ladDependency=Join-Path $ladRuntime "mods/$ladMod/release"
 New-Item -ItemType Directory -Force -Path $ladDependency | Out-Null
 Get-ChildItem -LiteralPath (Join-Path $ladGame "mods/$ladMod/release") -File | Where-Object Extension -In '.swf','.txt','.json','.xml' | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination $ladDependency -Force}
 $ladEntries+="${ladMod}Mod";$ladHashes+=Join-Path $ladDependency "${ladMod}Mod.swf"
}}
$ladDescriptor=Join-Path $ladRuntime 'application.xml'
$ladXml="<?xml version='1.0'?><application xmlns='http://ns.adobe.com/air/application/30.0'><id>$ladId</id><versionNumber>1.0</versionNumber><filename>LightMachineProbe</filename><initialWindow><content>pfe.swf</content><visible>false</visible><width>1280</width><height>800</height><renderMode>direct</renderMode></initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>"
[IO.File]::WriteAllText($ladDescriptor,$ladXml,[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $ladRuntime 'machine-mode.txt'),$Mode,[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $ladRuntime 'expected-version.txt'),$ExpectedVersion,[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $ladRuntime 'test-mode.txt'),$(if($Mixed){'mixed'}else{'single'}),[Text.UTF8Encoding]::new($false))
# The launcher selects the isolated manifest; never rewrite the formal selection.
& (Join-Path $ladGame 'mods/ModLoader/RemainsModLauncher.exe') --root $ladRuntime --only ($ladEntries -join ',') --no-ui --report (Join-Path $ladEvidence 'selection.json') | Out-String | Write-Output
if($LASTEXITCODE -ne 0){throw 'Launcher selection failed'}
$ladStorage=Join-Path $env:APPDATA "$ladId/Local Store"
try {
 & $Python (Join-Path $PSScriptRoot 'run-hidden.py') $ladGame $ladRuntime $ladEvidence $ladStorage $Timeout
 if($LASTEXITCODE -ne 0){throw 'Private desktop runner failed; no foreground fallback'}
}finally{
 if(Test-Path -LiteralPath $ladStorage){Copy-Item -LiteralPath $ladStorage -Destination (Join-Path $ladEvidence 'storage') -Recurse}
 Get-FileHash -LiteralPath $ladHashes | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $ladEvidence 'hashes.json')
 Remove-Item -LiteralPath $ladDescriptor
}
Write-Output "Evidence: $ladEvidence"
Get-Content -LiteralPath (Join-Path $ladEvidence 'storage/machine-test.log') -Tail 12
if(!(Select-String -LiteralPath (Join-Path $ladEvidence 'storage/machine-test.log') -Pattern '^SUITE_PASS' -Quiet)){throw 'Machine probe failed'}
$ladLoaded=Get-Content -LiteralPath (Join-Path $ladEvidence 'storage/loader.json') -Raw | ConvertFrom-Json
$ladMeta=Get-Content -LiteralPath (Join-Path $ladEvidence 'process.json') -Raw | ConvertFrom-Json
if($ladLoaded.session -notmatch '^run_(\d{13})_\d+$' -or [long]$Matches[1] -lt $ladMeta.startedMs -or [long]$Matches[1] -gt $ladMeta.endedMs){throw 'Missing or stale loader session'}
foreach($ladPrefix in @('requested_','ok_')){
 $ladActual=@($ladLoaded.psobject.Properties.Name | Where-Object {$_ -like "$ladPrefix*"} | ForEach-Object {$_.Substring($ladPrefix.Length)})
 if(Compare-Object ($ladEntries | Sort-Object) ($ladActual | Sort-Object)){throw "Actual load differs from selection: $ladPrefix"}
}
if($null -eq $ladLoaded.boot -or $null -eq $ladLoaded.boot_start -or @($ladLoaded.psobject.Properties.Name | Where-Object {$_ -like 'err_*'}).Count){throw 'Loader did not complete cleanly'}
Write-Output 'PASS fresh loader session and exact requested/initialized selection'
if($Mode -ne 'atlas'){
 $ladLog=Get-Content -LiteralPath (Join-Path $ladEvidence 'storage/LightAndDarkness.log') -Raw
 $ladVersion=if($Mode -eq 'baseline' -or $Mode -eq 'border'){'0.3.1'}else{$ExpectedVersion}
 if($ladLog -notmatch ('v'+[regex]::Escape($ladVersion)+' loaded') -or $ladLog -notmatch 'heartbeat' -or $ladLog -match 'FRAME_ERROR|ATTACH_FAILED|PREPARE_FAILED|RESTORE_FAILED'){throw 'Missing current version/heartbeat or runtime error'}
 Write-Output "PASS v$ladVersion loaded, heartbeat and no runtime errors"
}
