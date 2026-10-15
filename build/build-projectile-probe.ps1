param([string]$Java='D:\Program Files\Adobe Animate 2024\jre\bin\java.exe',[string]$Tools,[switch]$ProbeOnly,[string]$OutputDirectory='')
$ErrorActionPreference='Stop'
if (!$Tools) {throw 'Explicit read-only tool path required for isolated worktree'}
if (!$ProbeOnly) {
    & (Join-Path $PSScriptRoot 'build.ps1') -Java $Java -Tools $Tools -OutputDirectory $OutputDirectory
    if ($LASTEXITCODE -ne 0) {throw 'Candidate build failed'}
}
$modRoot=Split-Path $PSScriptRoot -Parent
$out=Join-Path $PSScriptRoot 'out'
if ($OutputDirectory) {$out=[IO.Path]::GetFullPath($OutputDirectory)}
New-Item -ItemType Directory -Force -Path $out,(Join-Path $PSScriptRoot 'generated') | Out-Null
$air=Join-Path $Tools 'airsdk/frameworks/libs/air/airglobal.swc'
$flex=Join-Path $Tools 'flexsdk'
$source=[Security.SecurityElement]::Escape((Join-Path $modRoot 'tests'))
$config=Join-Path $PSScriptRoot 'generated/projectile-probe.xml'
[IO.File]::WriteAllText($config,("<flex-config xmlns='http://www.adobe.com/2006/flex-config'><target-player>32.0</target-player><compiler><source-path><path-element>"+$source+"</path-element></source-path><external-library-path><path-element>"+[Security.SecurityElement]::Escape($air)+"</path-element></external-library-path><debug>false</debug><optimize>true</optimize></compiler></flex-config>"),[Text.UTF8Encoding]::new($false))
& $Java '-Xmx768m' '-jar' (Join-Path $flex 'lib/mxmlc.jar') "+flexlib=$flex/frameworks" "-load-config=$config" '-swf-version=32' '-use-network=false' '-static-link-runtime-shared-libraries=true' ("-output="+(Join-Path $out 'LightAndDarknessProjectileProbe.swf')) (Join-Path $modRoot 'tests/LightAndDarknessProjectileProbe.as')
if ($LASTEXITCODE -ne 0) {throw 'Projectile probe build failed'}
