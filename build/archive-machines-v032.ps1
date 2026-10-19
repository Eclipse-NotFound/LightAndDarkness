param([Parameter(Mandatory=$true)][string]$SmokeId)
$ErrorActionPreference='Stop'
$ladRoot=Split-Path $PSScriptRoot -Parent
$ladReceipt=Get-Content -LiteralPath (Join-Path $ladRoot 'state/machine-deployment-2026-10-19.json') -Raw | ConvertFrom-Json
$ladSets=[ordered]@{
 'native-art'='remains-lad-machine-20261019164122257'
 'initial-border-failure'='remains-lad-machine-20261019171305109'
 'legacy-baseline'='remains-lad-machine-20261019171854058'
 'candidate-checks'=$ladReceipt.evidence[0]
 'candidate-regression'=$ladReceipt.evidence[1]
 'installed-checks'=$SmokeId
}
$ladDestination=Join-Path $ladRoot 'tests/evidence/2026-10-19/machines-v032'
foreach($ladSet in $ladSets.GetEnumerator()){
 if($ladSet.Value -notmatch '^remains-lad-machine-\d{17}$'){throw 'Invalid evidence identity'}
 $ladSource=Join-Path $ladRoot ('build/evidence/'+$ladSet.Value)
 $ladTarget=Join-Path $ladDestination $ladSet.Key
 New-Item -ItemType Directory -Force -Path $ladTarget | Out-Null
 foreach($ladFile in @('selection.json','process.json','hashes.json','storage/machine-test.log','storage/test.log','storage/LightAndDarkness.log','storage/loader.json')){
  $ladPath=Join-Path $ladSource $ladFile
  if(Test-Path -LiteralPath $ladPath){Copy-Item -LiteralPath $ladPath -Destination $ladTarget -Force}
 }
 $ladPictures=if($ladSet.Key -eq 'native-art'){@('native-atlas.png','native-tree.json')}elseif($ladSet.Key -eq 'candidate-regression'){@('large-mixed.png')}elseif($ladSet.Key -eq 'installed-checks'){@('machines-after.png','machines-before.png','game-microglow-on.png','game-microglow-off.png')}else{@()}
 foreach($ladFile in $ladPictures){Copy-Item -LiteralPath (Join-Path $ladSource "storage/$ladFile") -Destination $ladTarget -Force}
 [IO.File]::WriteAllText((Join-Path $ladTarget 'run-id.txt'),$ladSet.Value,[Text.UTF8Encoding]::new($false))
}
Write-Output "Archived evidence: $ladDestination"
