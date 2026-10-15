param([Parameter(Mandatory=$true)][string]$Candidate,[string]$ExpectedHash='3BA6A9C93F20C6515648097E621556DC6DC8AB191780D83250CFAF27BB23BB9C')
$ErrorActionPreference='Stop'
$ladRoot=Split-Path $PSScriptRoot -Parent
$ladGame=Split-Path (Split-Path $ladRoot -Parent) -Parent
$ladRuntime=Join-Path $ladRoot 'build/generated/edge-game-runtime'
$ladId='remains-lad-edge-game-'+(Get-Date -Format 'yyyyMMddHHmmssfff')
$ladEvidence=Join-Path $ladRoot ('build/evidence/'+$ladId)
if((Get-FileHash -LiteralPath $Candidate).Hash -ne $ExpectedHash){throw 'Frozen candidate changed'}
New-Item -ItemType Directory -Force -Path $ladRuntime,$ladEvidence | Out-Null
$ladAssets=@('pfe.swf','texture.swf','texture1.swf','sprite.swf','sprite1.swf','sound.swf','sound_unit.swf','sound_weapon.swf','lang.xml','rooms.xml')
$ladAssets+=(Get-ChildItem -LiteralPath $ladGame -Filter 'text_*.xml').Name
foreach($ladAsset in $ladAssets){Copy-Item -LiteralPath (Join-Path $ladGame $ladAsset) -Destination $ladRuntime -Force}
if(!(Test-Path -LiteralPath (Join-Path $ladRuntime 'Rooms'))){Copy-Item -LiteralPath (Join-Path $ladGame 'Rooms') -Destination $ladRuntime -Recurse}
$ladRelease=Join-Path $ladRuntime 'mods/LightAndDarkness/release'
New-Item -ItemType Directory -Force -Path $ladRelease | Out-Null
Copy-Item -LiteralPath $Candidate -Destination (Join-Path $ladRelease 'LightAndDarknessMod.swf') -Force
Copy-Item -LiteralPath (Join-Path $ladRoot 'build/out/edge-fix/LightEdgeGameProbe.swf') -Destination $ladRelease -Force
Copy-Item -LiteralPath (Join-Path $ladRoot 'atmosphere.json') -Destination (Join-Path (Split-Path $ladRelease -Parent) 'atmosphere.json') -Force
[IO.File]::WriteAllText((Join-Path $ladRuntime 'mods/loader-manifest.txt'),"LightAndDarkness|LightAndDarknessMod|1|0|0`nLightAndDarkness|LightEdgeGameProbe|1|0|0`n",[Text.UTF8Encoding]::new($false))
$ladDescriptor=Join-Path $ladRuntime 'app_lad_edge_test.xml'
$ladXml="<?xml version='1.0'?><application xmlns='http://ns.adobe.com/air/application/30.0'><id>$ladId</id><versionNumber>1.0</versionNumber><filename>LightEdgeGameProbe</filename><initialWindow><content>pfe.swf</content><visible>false</visible><width>800</width><height>600</height><renderMode>direct</renderMode></initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>"
[IO.File]::WriteAllText($ladDescriptor,$ladXml,[Text.UTF8Encoding]::new($false))
$ladStorage=Join-Path $env:APPDATA "$ladId/Local Store"
$ladProcess=$null
try {
    $ladProcess=Start-Process -FilePath (Join-Path $ladGame 'adl64.exe') -ArgumentList ('-runtime "'+(Join-Path $ladGame 'runtimes/air/win64')+'" "'+$ladDescriptor+'" -nodebug') -WorkingDirectory $ladRuntime -WindowStyle Hidden -PassThru
    $ladDeadline=[DateTime]::UtcNow.AddSeconds(150)
    $ladLog=Join-Path $ladStorage 'edge-test.log'
    while(!$ladProcess.HasExited -and [DateTime]::UtcNow -lt $ladDeadline){
        if((Test-Path -LiteralPath $ladLog) -and (Select-String -LiteralPath $ladLog -Pattern '^(SUITE_PASS|FAIL )' -Quiet)){break}
        Start-Sleep -Milliseconds 250
    }
} finally {
    if($ladProcess -and !$ladProcess.HasExited){Stop-Process -Id $ladProcess.Id -Force}
    if(Test-Path -LiteralPath $ladStorage){Copy-Item -LiteralPath $ladStorage -Destination (Join-Path $ladEvidence 'storage') -Recurse}
    Get-FileHash -LiteralPath $Candidate,(Join-Path $ladRuntime 'pfe.swf'),(Join-Path $ladRelease 'LightEdgeGameProbe.swf') | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $ladEvidence 'hashes.json')
    Remove-Item -LiteralPath $ladDescriptor
}
Write-Output "Evidence: $ladEvidence"
Get-Content -LiteralPath (Join-Path $ladEvidence 'storage/edge-test.log')
if(!(Select-String -LiteralPath (Join-Path $ladEvidence 'storage/edge-test.log') -Pattern '^SUITE_PASS$' -Quiet)){throw 'Frozen edge probe failed'}
