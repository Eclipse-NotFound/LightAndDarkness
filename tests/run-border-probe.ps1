param([switch]$Mixed,[int]$Width=2560,[int]$Height=960,[switch]$ExpectFixed,[string]$Candidate='')
$ErrorActionPreference='Stop'
$ladRoot=Split-Path $PSScriptRoot -Parent
$ladGame=Split-Path (Split-Path $ladRoot -Parent) -Parent
$ladRuntime=Join-Path $ladRoot 'build/generated/border-runtime'
$ladId='remains-lad-border-'+(Get-Date -Format 'yyyyMMddHHmmssfff')
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
Copy-Item -LiteralPath (Join-Path $ladRoot 'build/out/border-diagnosis/LightBorderProbe.swf') -Destination $ladRelease -Force
Copy-Item -LiteralPath (Join-Path $ladRoot 'atmosphere.json') -Destination (Join-Path (Split-Path $ladRelease -Parent) 'atmosphere.json') -Force
$ladManifest="LightAndDarkness|LightAndDarknessMod|1|0|0`nLightAndDarkness|LightBorderProbe|1|0|0`n"
$ladHashes=@((Join-Path $ladRuntime 'pfe.swf'),(Join-Path $ladRelease 'LightAndDarknessMod.swf'),(Join-Path $ladRelease 'LightBorderProbe.swf'))
if($Mixed){foreach($ladMod in @('ModLoader','ContinuousScene','RealisticVision','WallBlend')){
    $ladDependency=Join-Path $ladRuntime "mods/$ladMod/release"
    New-Item -ItemType Directory -Force -Path $ladDependency | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $ladGame "mods/$ladMod/release") -File | Where-Object Extension -In '.swf','.txt','.json','.xml' | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination $ladDependency -Force}
    $ladManifest+="$ladMod|${ladMod}Mod|1|0|0`n";$ladHashes+=Join-Path $ladDependency "${ladMod}Mod.swf"
}}
[IO.File]::WriteAllText((Join-Path $ladRuntime 'mods/loader-manifest.txt'),$ladManifest,[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $ladRuntime 'border-mode.txt'),$(if($ExpectFixed){'fixed'}else{'diagnosis'}),[Text.UTF8Encoding]::new($false))
$ladDescriptor=Join-Path $ladRuntime 'app_lad_border_test.xml'
$ladXml="<?xml version='1.0'?><application xmlns='http://ns.adobe.com/air/application/30.0'><id>$ladId</id><versionNumber>1.0</versionNumber><filename>LightBorderProbe</filename><initialWindow><content>pfe.swf</content><visible>false</visible><width>$Width</width><height>$Height</height><renderMode>direct</renderMode></initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>"
[IO.File]::WriteAllText($ladDescriptor,$ladXml,[Text.UTF8Encoding]::new($false))
$ladStorage=Join-Path $env:APPDATA "$ladId/Local Store"
$ladProcess=$null
try {
    $ladProcess=Start-Process -FilePath (Join-Path $ladGame 'adl64.exe') -ArgumentList ('-runtime "'+(Join-Path $ladGame 'runtimes/air/win64')+'" "'+$ladDescriptor+'" -nodebug') -WorkingDirectory $ladRuntime -WindowStyle Hidden -PassThru
    $ladDeadline=[DateTime]::UtcNow.AddSeconds(180)
    $ladLog=Join-Path $ladStorage 'border-test.log'
    while(!$ladProcess.HasExited -and [DateTime]::UtcNow -lt $ladDeadline){
        if((Test-Path -LiteralPath $ladLog) -and (Select-String -LiteralPath $ladLog -Pattern '^(SUITE_PASS|FAIL )' -Quiet)){break}
        Start-Sleep -Milliseconds 250
    }
} finally {
    if($ladProcess -and !$ladProcess.HasExited){Stop-Process -Id $ladProcess.Id -Force}
    if(Test-Path -LiteralPath $ladStorage){Copy-Item -LiteralPath $ladStorage -Destination (Join-Path $ladEvidence 'storage') -Recurse}
    Get-FileHash -LiteralPath $ladHashes | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $ladEvidence 'hashes.json')
    Remove-Item -LiteralPath $ladDescriptor
}
Write-Output "Evidence: $ladEvidence"
Get-Content -LiteralPath (Join-Path $ladEvidence 'storage/border-test.log')
if(!(Select-String -LiteralPath (Join-Path $ladEvidence 'storage/border-test.log') -Pattern '^SUITE_PASS$' -Quiet)){throw 'Border diagnosis probe failed'}
