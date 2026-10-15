param(
    [Parameter(Mandatory=$true)][string]$RegressionEvidence,
    [Parameter(Mandatory=$true)][string]$ProjectileEvidence,
    [Parameter(Mandatory=$true)][string]$KeyEvidence,
    [switch]$Install
)
$ErrorActionPreference='Stop'
$modRoot=Split-Path $PSScriptRoot -Parent
$gameRoot=Split-Path (Split-Path $modRoot -Parent) -Parent
$candidate=Join-Path $PSScriptRoot 'out/projectiles-v030/LightAndDarknessMod.swf'
$target=Join-Path $modRoot 'release/LightAndDarknessMod.swf'
$newHash='3BA6A9C93F20C6515648097E621556DC6DC8AB191780D83250CFAF27BB23BB9C'
$oldHash='488BDC73A0BD843138FB9CABF6AC0B81159493838E3DAD4B2916688CE4C597F1'
$expected=[ordered]@{
    'pfe.swf'='11BCECA88365AB00A29A99511380CBAFA35F18CE9BF4465BE66FDAD16AD1BD4F'
    'mods/ContinuousScene/release/ContinuousSceneMod.swf'='F6ED93AFF2BFB76B4AE8CA2A2E01B84BBE4D24A8DD59EB4DE720847C8457D8D2'
    'mods/RealisticVision/release/RealisticVisionMod.swf'='BAA48289D9CF86F64CFF53B4734032AD29C89C3AC1704DB2D89038D4B8DB4275'
    'mods/WallBlend/release/WallBlendMod.swf'='3B1B40A65D7C57E4711C3861463B3470B0DFC086A8C8C01870C91A2F413DA96F'
    'mods/ModLoader/release/ModLoaderMod.swf'='BD71B6F31774B97841D4C158451DA0353B53BC46AC72F8E2A7FE2C3F3F4908B1'
}
function Hash([string]$path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
function RequireHash([string]$path,[string]$expectedHash) {
    if ((Hash $path) -ne $expectedHash) {throw "Unreviewed file change: $path"}
}
function VerifyEvidence([string]$id,[string]$logName,[int]$minimum,[bool]$mixed) {
    if ($id -notmatch '^remains-lad-(test|projectile|keybind)-\d{17}$') {throw 'Invalid evidence identity'}
    $root=Join-Path $modRoot "build/evidence/$id"
    $log=Get-Content -LiteralPath (Join-Path $root "storage/$logName")
    if (!($log -match '^\d+ SUITE_PASS$') -or ($log -match '^\d+ FAIL ') -or @($log -match '^\d+ PASS ').Count -lt $minimum) {throw "Incomplete checks: $id"}
    $hashes=Get-Content -LiteralPath (Join-Path $root 'candidate-hashes.json') -Raw | ConvertFrom-Json
    $wanted=@{'LightAndDarknessMod.swf'=$newHash;'pfe.swf'=$expected['pfe.swf'];'ModLoaderMod.swf'=$expected['mods/ModLoader/release/ModLoaderMod.swf']}
    if ($mixed) {foreach ($entry in $expected.GetEnumerator()) {$wanted[[IO.Path]::GetFileName($entry.Key)]=$entry.Value}}
    foreach ($name in $wanted.Keys) {
        $found=@($hashes | Where-Object {[IO.Path]::GetFileName($_.Path) -ceq $name})
        if ($found.Count -ne 1 -or $found[0].Hash -ne $wanted[$name]) {throw "Evidence byte mismatch: $id / $name"}
    }
}
RequireHash $candidate $newHash
RequireHash $target $oldHash
foreach ($entry in $expected.GetEnumerator()) {RequireHash (Join-Path $gameRoot $entry.Key) $entry.Value}
[xml]$descriptor=Get-Content -LiteralPath (Join-Path $gameRoot 'application.xml') -Raw
if ($descriptor.application.initialWindow.content -cne 'pfe.swf') {throw 'Unexpected active game content'}
$manifestPath=Join-Path $gameRoot 'mods/loader-manifest.txt'
$rows=@(Get-Content -LiteralPath $manifestPath | Where-Object {$_ -match '^LightAndDarkness\|'})
if ($rows.Count -ne 1 -or $rows[0] -cne 'LightAndDarkness|LightAndDarknessMod|1|0|0') {throw 'Unexpected LightAndDarkness manifest row'}
$manifestHash=Hash $manifestPath
$descriptorHash=Hash (Join-Path $gameRoot 'application.xml')
VerifyEvidence $RegressionEvidence 'test.log' 81 $true
VerifyEvidence $ProjectileEvidence 'projectile-test.log' 131 $true
VerifyEvidence $KeyEvidence 'keybind-test.log' 21 $false
if (!$Install) {Write-Output 'PRECHECK_PASS: candidate, compatibility baseline and final-byte evidence match';return}

$backupRoot=Join-Path $PSScriptRoot ('backups/projectiles-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
if (Test-Path -LiteralPath $backupRoot) {throw 'Backup already exists'}
New-Item -ItemType Directory -Path $backupRoot | Out-Null
$backup=Join-Path $backupRoot 'LightAndDarknessMod.v0.2.2-scene.swf'
$staged=Join-Path $backupRoot 'LightAndDarknessMod.staged.swf'
Copy-Item -LiteralPath $target -Destination $backup
Copy-Item -LiteralPath $candidate -Destination $staged
RequireHash $backup $oldHash
RequireHash $staged $newHash
# Compare again immediately before the atomic single-file replacement.
RequireHash $target $oldHash
RequireHash $manifestPath $manifestHash
foreach ($entry in $expected.GetEnumerator()) {RequireHash (Join-Path $gameRoot $entry.Key) $entry.Value}
[IO.File]::Replace($staged,$target,$null)
RequireHash $target $newHash
RequireHash $manifestPath $manifestHash
RequireHash (Join-Path $gameRoot 'application.xml') $descriptorHash
foreach ($entry in $expected.GetEnumerator()) {RequireHash (Join-Path $gameRoot $entry.Key) $entry.Value}
$receipt=[ordered]@{version='0.3.0';installedAt=(Get-Date -Format o);target=$target;sha256=$newHash;previousSha256=$oldHash;backup=$backup;hostAndDependencies=$expected;manifestSha256=$manifestHash;descriptorSha256=$descriptorHash;evidence=@($RegressionEvidence,$ProjectileEvidence,$KeyEvidence);restartSmoke='pending';rollback='Restore only this backup if current release still matches sha256; preserve current host, manifest and other mods.'}
$receiptPath=Join-Path $modRoot 'state/projectile-deployment-2026-10-15.json'
[IO.File]::WriteAllText($receiptPath,($receipt | ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
Write-Output "DEPLOYED: $newHash"
Write-Output "Backup: $backup"
Write-Output "Receipt: $receiptPath"
