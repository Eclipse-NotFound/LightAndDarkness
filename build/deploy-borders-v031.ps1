param([Parameter(Mandatory=$true)][string]$BorderEvidence,
      [Parameter(Mandatory=$true)][string]$RegressionEvidence,[switch]$Install)
$ErrorActionPreference='Stop'
$ladRoot=Split-Path $PSScriptRoot -Parent
$ladGame=Split-Path (Split-Path $ladRoot -Parent) -Parent
$ladCandidate=Join-Path $PSScriptRoot 'out/borders-v031/LightAndDarknessMod.swf'
$ladTarget=Join-Path $ladRoot 'release/LightAndDarknessMod.swf'
$ladNewHash='514A7671D4DA517A31045AEAF8FFAD3089AA66705FE58D14DC339F849589A7F6'
$ladOldHash='3BA6A9C93F20C6515648097E621556DC6DC8AB191780D83250CFAF27BB23BB9C'
$ladExpected=[ordered]@{
 'pfe.swf'='08A96759720C7A2AA489FCEEDB209C6E704500FDE7B1A4A49146BD578E99A8BC'
 'mods/ContinuousScene/release/ContinuousSceneMod.swf'='F6ED93AFF2BFB76B4AE8CA2A2E01B84BBE4D24A8DD59EB4DE720847C8457D8D2'
 'mods/RealisticVision/release/RealisticVisionMod.swf'='BAA48289D9CF86F64CFF53B4734032AD29C89C3AC1704DB2D89038D4B8DB4275'
 'mods/WallBlend/release/WallBlendMod.swf'='3B1B40A65D7C57E4711C3861463B3470B0DFC086A8C8C01870C91A2F413DA96F'
 'mods/ModLoader/release/ModLoaderMod.swf'='BD71B6F31774B97841D4C158451DA0353B53BC46AC72F8E2A7FE2C3F3F4908B1'
 'mods/loader-manifest.txt'='778B8D1E551E69F4A16B3F4131141FBE4B1E35E9E9EFF2F360593182B5C07D6C'
}
function Hash([string]$path){(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash}
function RequireHash([string]$path,[string]$expected){if((Hash $path) -ne $expected){throw "Unreviewed change: $path"}}
function VerifyEvidence([string]$id,[bool]$border){
 if($id -notmatch '^remains-lad-(border|test)-\d{17}$'){throw 'Invalid evidence identity'}
 $root=Join-Path $ladRoot "build/evidence/$id"
 if($border){
  $report=Get-Content -LiteralPath (Join-Path $root 'storage/border-report.json') -Raw | ConvertFrom-Json
  if($report.status -ne 'passed' -or !$report.expectFixed -or $report.checks.Count -lt 17 -or @($report.checks | Where-Object {!$_.pass}).Count){throw 'Border regression did not pass'}
  $hashes=Get-Content -LiteralPath (Join-Path $root 'hashes.json') -Raw | ConvertFrom-Json
 }else{
  $log=Get-Content -LiteralPath (Join-Path $root 'storage/test.log')
  if(!($log -match '^\d+ SUITE_PASS$') -or ($log -match '^\d+ FAIL ') -or @($log -match '^\d+ PASS ').Count -lt 89){throw 'Incomplete ordinary/large-scene regression'}
  $hashes=Get-Content -LiteralPath (Join-Path $root 'candidate-hashes.json') -Raw | ConvertFrom-Json
 }
 $wanted=@{'LightAndDarknessMod.swf'=$ladNewHash}
 foreach($entry in $ladExpected.GetEnumerator()){if($entry.Key.EndsWith('.swf')){$wanted[[IO.Path]::GetFileName($entry.Key)]=$entry.Value}}
 foreach($name in $wanted.Keys){
  $found=@($hashes | Where-Object {[IO.Path]::GetFileName($_.Path) -ceq $name})
  if($found.Count -ne 1 -or $found[0].Hash -ne $wanted[$name]){throw "Evidence byte mismatch: $id / $name"}
 }
 $runtimeLog=Get-Content -LiteralPath (Join-Path $root 'storage/LightAndDarkness.log') -Raw
 if($runtimeLog -notmatch 'v0\.3\.1 loaded' -or $runtimeLog -notmatch 'heartbeat' -or $runtimeLog -match '(FRAME_ERROR|ATTACH_FAILED|RESTORE_FAILED|PREPARE_FAILED)'){throw "Runtime failure: $id"}
}
RequireHash $ladCandidate $ladNewHash
RequireHash $ladTarget $ladOldHash
foreach($entry in $ladExpected.GetEnumerator()){RequireHash (Join-Path $ladGame $entry.Key) $entry.Value}
$ladDescriptor=Join-Path $ladGame 'application.xml'
[xml]$ladXml=Get-Content -LiteralPath $ladDescriptor -Raw
if($ladXml.application.initialWindow.content -cne 'pfe.swf'){throw 'Unexpected active content'}
$ladDescriptorHash=Hash $ladDescriptor
$ladRows=@(Get-Content -LiteralPath (Join-Path $ladGame 'mods/loader-manifest.txt') | Where-Object {$_ -match '^LightAndDarkness\|'})
if($ladRows.Count -ne 1 -or $ladRows[0] -cne 'LightAndDarkness|LightAndDarknessMod|1|0|0'){throw 'Unexpected manifest row'}
VerifyEvidence $BorderEvidence $true
VerifyEvidence $RegressionEvidence $false
if(!$Install){Write-Output 'PRECHECK_PASS: frozen candidate and compatibility evidence match';return}
$ladBackupRoot=Join-Path $PSScriptRoot ('backups/borders-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
if(Test-Path -LiteralPath $ladBackupRoot){throw 'Backup exists'}
New-Item -ItemType Directory -Path $ladBackupRoot | Out-Null
$ladBackup=Join-Path $ladBackupRoot 'LightAndDarknessMod.v0.3.0.swf'
$ladStaged=Join-Path $ladBackupRoot 'LightAndDarknessMod.staged.swf'
$ladAtomic=Join-Path $ladBackupRoot 'LightAndDarknessMod.atomic-backup.swf'
Copy-Item -LiteralPath $ladTarget -Destination $ladBackup
Copy-Item -LiteralPath $ladCandidate -Destination $ladStaged
RequireHash $ladBackup $ladOldHash
RequireHash $ladStaged $ladNewHash
RequireHash $ladTarget $ladOldHash
RequireHash $ladDescriptor $ladDescriptorHash
foreach($entry in $ladExpected.GetEnumerator()){RequireHash (Join-Path $ladGame $entry.Key) $entry.Value}
[IO.File]::Replace($ladStaged,$ladTarget,$ladAtomic)
RequireHash $ladAtomic $ladOldHash
RequireHash $ladTarget $ladNewHash
RequireHash $ladDescriptor $ladDescriptorHash
foreach($entry in $ladExpected.GetEnumerator()){RequireHash (Join-Path $ladGame $entry.Key) $entry.Value}
$ladReceipt=[ordered]@{version='0.3.1';installedAt=(Get-Date -Format o);target=$ladTarget;sha256=$ladNewHash;previousSha256=$ladOldHash;backup=$ladBackup;hostAndDependencies=$ladExpected;descriptorSha256=$ladDescriptorHash;evidence=@($BorderEvidence,$RegressionEvidence);restartSmoke='pending';rollback='Restore only this backup if release still matches sha256. Preserve host, manifest, other mods and real saves.'}
$ladReceiptPath=Join-Path $ladRoot 'state/border-deployment-2026-10-16.json'
[IO.File]::WriteAllText($ladReceiptPath,($ladReceipt | ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
Write-Output "DEPLOYED: $ladNewHash"
Write-Output "Backup: $ladBackup"
