param([string]$Java='D:/Program Files/Adobe Animate 2024/jre/bin/java.exe',[string]$Tools='D:/Program Files/Steam/steamapps/common/Remains/mods/Sandevistan/build/tools')
$ErrorActionPreference='Stop'
$ladRoot=Split-Path $PSScriptRoot -Parent
$ladOut=Join-Path $PSScriptRoot 'out/machines-v032'
New-Item -ItemType Directory -Force -Path $ladOut,(Join-Path $PSScriptRoot 'generated') | Out-Null
$ladSource=[Security.SecurityElement]::Escape((Join-Path $ladRoot 'tests'))
$ladAir=[Security.SecurityElement]::Escape((Join-Path $Tools 'airsdk/frameworks/libs/air/airglobal.swc'))
$ladConfig=Join-Path $PSScriptRoot 'generated/machine-probe.xml'
[IO.File]::WriteAllText($ladConfig,"<flex-config xmlns='http://www.adobe.com/2006/flex-config'><target-player>32.0</target-player><compiler><source-path><path-element>$ladSource</path-element></source-path><external-library-path><path-element>$ladAir</path-element></external-library-path><debug>false</debug><optimize>true</optimize></compiler></flex-config>",[Text.UTF8Encoding]::new($false))
& $Java '-Xmx768m' '-jar' (Join-Path $Tools 'flexsdk/lib/mxmlc.jar') ('+flexlib='+(Join-Path $Tools 'flexsdk/frameworks')) "-load-config=$ladConfig" '-swf-version=32' '-use-network=false' '-static-link-runtime-shared-libraries=true' ('-output='+(Join-Path $ladOut 'LightMachineProbeMod.swf')) (Join-Path $ladRoot 'tests/LightMachineProbeMod.as')
if($LASTEXITCODE -ne 0){throw 'Machine probe build failed'}
