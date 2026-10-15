param([string]$Java='D:/Program Files/Adobe Animate 2024/jre/bin/java.exe',[string]$Tools='D:/Program Files/Steam/steamapps/common/Remains/mods/Sandevistan/build/tools')
$ErrorActionPreference='Stop'
$ladRoot=Split-Path $PSScriptRoot -Parent
$ladOut=Join-Path $PSScriptRoot 'out/edge-fix'
New-Item -ItemType Directory -Force -Path $ladOut | Out-Null
$ladBaselineDir=Join-Path $PSScriptRoot 'generated/aa-probe/lad'
New-Item -ItemType Directory -Force -Path $ladBaselineDir | Out-Null
$ladBaseline=(git -C $ladRoot show e21e914:src/lad/LadLightField.as) -join "`n"
if($LASTEXITCODE -ne 0){throw 'Missing deployed baseline source'}
$ladBaseline=$ladBaseline.Replace('public final class LadLightField','public final class LadLightFieldBeforeAA').Replace('public function LadLightField()','public function LadLightFieldBeforeAA()')
[IO.File]::WriteAllText((Join-Path $ladBaselineDir 'LadLightFieldBeforeAA.as'),$ladBaseline,[Text.UTF8Encoding]::new($false))
$ladSources=@((Join-Path $ladRoot 'tests'),(Join-Path $ladRoot 'src'),(Join-Path $PSScriptRoot 'generated/aa-probe'))
$ladSourceXml=($ladSources | ForEach-Object {'<path-element>'+[Security.SecurityElement]::Escape($_)+'</path-element>'}) -join ''
$ladAir=[Security.SecurityElement]::Escape((Join-Path $Tools 'airsdk/frameworks/libs/air/airglobal.swc'))
$ladConfig=Join-Path $PSScriptRoot 'generated/edge-probe.xml'
[IO.File]::WriteAllText($ladConfig,"<flex-config xmlns='http://www.adobe.com/2006/flex-config'><target-player>32.0</target-player><compiler><source-path>$ladSourceXml</source-path><external-library-path><path-element>$ladAir</path-element></external-library-path><debug>false</debug><optimize>true</optimize></compiler></flex-config>",[Text.UTF8Encoding]::new($false))
& $Java '-Xmx768m' '-jar' (Join-Path $Tools 'flexsdk/lib/mxmlc.jar') ('+flexlib='+(Join-Path $Tools 'flexsdk/frameworks')) "-load-config=$ladConfig" '-swf-version=32' '-use-network=false' '-static-link-runtime-shared-libraries=true' ('-output='+(Join-Path $ladOut 'LightEdgeProbe.swf')) (Join-Path $ladRoot 'tests/LightEdgeProbe.as')
if($LASTEXITCODE -ne 0){throw 'Edge probe build failed'}
& $Java '-Xmx768m' '-jar' (Join-Path $Tools 'flexsdk/lib/mxmlc.jar') ('+flexlib='+(Join-Path $Tools 'flexsdk/frameworks')) "-load-config=$ladConfig" '-swf-version=32' '-use-network=false' '-static-link-runtime-shared-libraries=true' ('-output='+(Join-Path $ladOut 'LightEdgeGameProbe.swf')) (Join-Path $ladRoot 'tests/LightEdgeGameProbe.as')
if($LASTEXITCODE -ne 0){throw 'Frozen candidate probe build failed'}
