param([Parameter(Mandatory=$true)][string]$MachineEvidence,
 [Parameter(Mandatory=$true)][string]$RegressionEvidence,[switch]$Install)
$ErrorActionPreference='Stop'
$ladRoot=Split-Path $PSScriptRoot -Parent
$ladGame=Split-Path (Split-Path $ladRoot -Parent) -Parent
$ladCandidate=Join-Path $PSScriptRoot 'out/machines-v032/LightAndDarknessMod.swf'
$ladTarget=Join-Path $ladRoot 'release/LightAndDarknessMod.swf'
$ladNew='3835827D0D2702EC55AB13721DCED7D8463C3A69780C6C37B5816BBD72164B46'
$ladOld='514A7671D4DA517A31045AEAF8FFAD3089AA66705FE58D14DC339F849589A7F6'
$ladExpected=[ordered]@{
 'pfe.swf'='02BFABE6A3B4881DFA1227515E71F2A8EA863D4B1B468FBE1D8008AEBA7D9240'
 'application.xml'='70DD3B085E5F6C66C03693CF68CE5E93A4E4136DD745D40D1A5B2A49863BA236'
 'mods/loader-manifest.txt'='33DE189E1209FDD397E811A52E9AC67FF0DEDAEEAE5CFEFF4B7D15D4536EB133'
 'mods/ContinuousScene/release/ContinuousSceneMod.swf'='B5E8110E11FE2DF8A748B223DFFA6E0EC42E4F61A931D4D4E065CC199EFA2F1B'
 'mods/RealisticVision/release/RealisticVisionMod.swf'='76314B819151FBA6F67F6D740B21030A9EEC8359AF4C9C9DDEB83D4CAF5C46B7'
 'mods/WallBlend/release/WallBlendMod.swf'='0BD209A1763D1C08BCEEAA6415DC768AB3D18AD99BAD377B4D8C188EBD48DE5A'
 'mods/ModLoader/release/ModLoaderMod.swf'='BD71B6F31774B97841D4C158451DA0353B53BC46AC72F8E2A7FE2C3F3F4908B1'
}
function RequireHash([string]$path,[string]$expected){if((Get-FileHash -LiteralPath $path).Hash -ne $expected){throw "Concurrent or unverified change: $path"}}
function VerifyEvidence([string]$id,[string]$mode){
 if($id -notmatch '^remains-lad-machine-\d{17}$'){throw 'Invalid evidence ID'}
 $e=Join-Path $ladRoot "build/evidence/$id"
 $log=Get-Content -LiteralPath (Join-Path $e 'storage/machine-test.log') -Raw
 if($log -notmatch "(?m)^SUITE_PASS $mode" -or $log -match '(?m)^(\d+ )?FAIL '){throw "Failed evidence: $id"}
 $count=@([regex]::Matches($log,'(?m)^(\d+ )?PASS ')).Count
 if(($mode -eq 'verify' -and $count -lt 173) -or ($mode -eq 'regression' -and $count -lt 99)){throw 'Incomplete behavioral verification'}
 $hashes=Get-Content -LiteralPath (Join-Path $e 'hashes.json') -Raw | ConvertFrom-Json
 $wanted=@{'LightAndDarknessMod.swf'=$ladNew}
 foreach($entry in $ladExpected.GetEnumerator()){if($entry.Key.EndsWith('.swf')){$wanted[[IO.Path]::GetFileName($entry.Key)]=$entry.Value}}
 foreach($name in $wanted.Keys){
  $found=@($hashes | Where-Object {[IO.Path]::GetFileName($_.Path) -ceq $name})
  if($found.Count -ne 1 -or $found[0].Hash -ne $wanted[$name]){throw "Evidence bytes differ: $name"}
 }
 $loaded=Get-Content -LiteralPath (Join-Path $e 'storage/loader.json') -Raw | ConvertFrom-Json
 $meta=Get-Content -LiteralPath (Join-Path $e 'process.json') -Raw | ConvertFrom-Json
 if($loaded.session -notmatch '^run_(\d{13})_\d+$' -or [long]$Matches[1] -lt $meta.startedMs -or [long]$Matches[1] -gt $meta.endedMs){throw 'Stale loader evidence'}
 $entries=@('LightAndDarknessMod','LightMachineProbeMod','ModLoaderMod','ContinuousSceneMod','RealisticVisionMod','WallBlendMod') | Sort-Object
 foreach($prefix in @('requested_','ok_')){
  $actual=@($loaded.psobject.Properties.Name | Where-Object {$_ -like "$prefix*"} | ForEach-Object {$_.Substring($prefix.Length)} | Sort-Object)
  if(Compare-Object $entries $actual){throw 'Loaded combination differs'}
 }
 if($null -eq $loaded.boot -or $null -eq $loaded.boot_start -or @($loaded.psobject.Properties.Name | Where-Object {$_ -like 'err_*'}).Count){throw 'Loader failure'}
 $runtime=Get-Content -LiteralPath (Join-Path $e 'storage/LightAndDarkness.log') -Raw
 if($runtime -notmatch 'v0\.3\.2 loaded' -or $runtime -notmatch 'heartbeat' -or $runtime -match 'FRAME_ERROR|ATTACH_FAILED|PREPARE_FAILED|RESTORE_FAILED'){throw 'Runtime verification failed'}
}
RequireHash $ladCandidate $ladNew
RequireHash $ladTarget $ladOld
foreach($entry in $ladExpected.GetEnumerator()){RequireHash (Join-Path $ladGame $entry.Key) $entry.Value}
[xml]$ladDescriptor=Get-Content -LiteralPath (Join-Path $ladGame 'application.xml') -Raw
if($ladDescriptor.application.initialWindow.content -cne 'pfe.swf'){throw 'Unexpected active host'}
$ladRows=@(Get-Content -LiteralPath (Join-Path $ladGame 'mods/loader-manifest.txt') | Where-Object {$_ -match '^LightAndDarkness\|'})
# Preserve the current launcher's selection exactly. Only active 1.02 is certified here.
if($ladRows.Count -ne 1 -or $ladRows[0] -cne 'LightAndDarkness|LightAndDarknessMod|1|1|1'){throw 'Unexpected installed entry'}
VerifyEvidence $MachineEvidence 'verify'
VerifyEvidence $RegressionEvidence 'regression'
if(!$Install){Write-Output 'PRECHECK_PASS frozen candidate, exact loader sessions and compatibility checks';return}
$ladBackupRoot=Join-Path $PSScriptRoot ('backups/machines-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
if(Test-Path -LiteralPath $ladBackupRoot){throw 'Backup collision'}
New-Item -ItemType Directory -Path $ladBackupRoot | Out-Null
$ladBackup=Join-Path $ladBackupRoot 'LightAndDarknessMod.v0.3.1.swf'
$ladStaged=Join-Path $ladBackupRoot 'LightAndDarknessMod.staged.swf'
$ladAtomic=Join-Path $ladBackupRoot 'LightAndDarknessMod.atomic-backup.swf'
Copy-Item -LiteralPath $ladTarget -Destination $ladBackup
Copy-Item -LiteralPath $ladCandidate -Destination $ladStaged
RequireHash $ladBackup $ladOld
RequireHash $ladStaged $ladNew
RequireHash $ladTarget $ladOld
foreach($entry in $ladExpected.GetEnumerator()){RequireHash (Join-Path $ladGame $entry.Key) $entry.Value}
[IO.File]::Replace($ladStaged,$ladTarget,$ladAtomic)
RequireHash $ladAtomic $ladOld
RequireHash $ladTarget $ladNew
foreach($entry in $ladExpected.GetEnumerator()){RequireHash (Join-Path $ladGame $entry.Key) $entry.Value}
$ladReceipt=[ordered]@{version='0.3.2';installedAt=(Get-Date -Format o);sha256=$ladNew;previousSha256=$ladOld;backup=$ladBackup;hostAndDependencies=$ladExpected;evidence=@($MachineEvidence,$RegressionEvidence);restartSmoke='pending';rollback='Restore only the saved v0.3.1 file if release still matches this sha256; preserve host, manifest, other mods and real saves.'}
[IO.File]::WriteAllText((Join-Path $ladRoot 'state/machine-deployment-2026-10-19.json'),($ladReceipt | ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
Write-Output "DEPLOYED $ladNew"
Write-Output "Backup: $ladBackup"
