$ErrorActionPreference='Stop'
$ladRoot=Split-Path $PSScriptRoot -Parent
$ladGame=Split-Path (Split-Path $ladRoot -Parent) -Parent
$ladRuntime=Join-Path $ladRoot 'build/out/edge-fix'
$ladId='remains-lad-edge-'+(Get-Date -Format 'yyyyMMddHHmmssfff')
$ladDescriptor=Join-Path $ladRuntime 'app_lad_edge_test.xml'
$ladEvidence=Join-Path $ladRoot ('build/evidence/'+$ladId)
New-Item -ItemType Directory -Force -Path $ladEvidence | Out-Null
$ladXml="<?xml version='1.0'?><application xmlns='http://ns.adobe.com/air/application/30.0'><id>$ladId</id><versionNumber>1.0</versionNumber><filename>LightEdgeProbe</filename><initialWindow><content>LightEdgeProbe.swf</content><visible>false</visible><width>800</width><height>600</height><renderMode>direct</renderMode></initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>"
[IO.File]::WriteAllText($ladDescriptor,$ladXml,[Text.UTF8Encoding]::new($false))
$ladStorage=Join-Path $env:APPDATA "$ladId/Local Store"
$ladProcess=$null
try {
    $ladProcess=Start-Process -FilePath (Join-Path $ladGame 'adl64.exe') -ArgumentList ('-runtime "'+(Join-Path $ladGame 'runtimes/air/win64')+'" "'+$ladDescriptor+'" -nodebug') -WorkingDirectory $ladRuntime -WindowStyle Hidden -PassThru
    $ladDeadline=[DateTime]::UtcNow.AddSeconds(60)
    $ladLog=Join-Path $ladStorage 'edge-test.log'
    while(!$ladProcess.HasExited -and [DateTime]::UtcNow -lt $ladDeadline){
        if((Test-Path -LiteralPath $ladLog) -and (Select-String -LiteralPath $ladLog -Pattern '^(SUITE_PASS|FAIL )' -Quiet)){break}
        Start-Sleep -Milliseconds 250
    }
} finally {
    if($ladProcess -and !$ladProcess.HasExited){Stop-Process -Id $ladProcess.Id -Force}
    if(Test-Path -LiteralPath $ladStorage){Copy-Item -LiteralPath $ladStorage -Destination (Join-Path $ladEvidence 'storage') -Recurse}
    Remove-Item -LiteralPath $ladDescriptor
}
Write-Output "Evidence: $ladEvidence"
Get-Content -LiteralPath (Join-Path $ladEvidence 'storage/edge-test.log')
if(!(Select-String -LiteralPath (Join-Path $ladEvidence 'storage/edge-test.log') -Pattern '^SUITE_PASS$' -Quiet)){throw 'Edge probe failed'}
