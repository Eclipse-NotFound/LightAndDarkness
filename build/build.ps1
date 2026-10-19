param(
    [string]$Java = 'D:\Program Files\Adobe Animate 2024\jre\bin\java.exe',
    [string]$Tools = '',
    [switch]$Tests,
    [switch]$TestsOnly,
    [string]$OutputDirectory = '',
    [string]$SourceDirectory = ''
)
$ErrorActionPreference = 'Stop'
$modRoot = Split-Path $PSScriptRoot -Parent
$gameRoot = Split-Path (Split-Path $modRoot -Parent) -Parent
if (!$SourceDirectory) { $SourceDirectory = Join-Path $modRoot 'src' }
$SourceDirectory = [IO.Path]::GetFullPath($SourceDirectory)
if (!$Tools) { $Tools = Join-Path $gameRoot 'mods\Sandevistan\build\tools' }
$flexRoot = Join-Path $Tools 'flexsdk'
$airSwc = Join-Path $Tools 'airsdk\frameworks\libs\air\airglobal.swc'
foreach ($required in @($Java, $airSwc, (Join-Path $flexRoot 'lib\mxmlc.jar'), (Join-Path $flexRoot 'lib\compc.jar'))) {
    if (!(Test-Path -LiteralPath $required)) { throw "Missing tool: $required" }
}
$out = Join-Path $PSScriptRoot 'out'
if ($OutputDirectory) { $out = [IO.Path]::GetFullPath($OutputDirectory) }
$generated = Join-Path $out 'config'
New-Item -ItemType Directory -Force -Path $out, $generated | Out-Null
function Write-Config([string]$Name, [string[]]$Sources, [string[]]$Libraries) {
    $sourcesXml = ($Sources | ForEach-Object { '<path-element>' + [Security.SecurityElement]::Escape($_) + '</path-element>' }) -join ''
    $libsXml = ($Libraries | ForEach-Object { '<path-element>' + [Security.SecurityElement]::Escape($_) + '</path-element>' }) -join ''
    $config = Join-Path $generated "$Name.xml"
    [IO.File]::WriteAllText($config, "<flex-config xmlns=`"http://www.adobe.com/2006/flex-config`"><target-player>32.0</target-player><compiler><source-path>$sourcesXml</source-path><external-library-path>$libsXml</external-library-path><debug>false</debug><optimize>true</optimize></compiler></flex-config>", [Text.UTF8Encoding]::new($false))
    return $config
}
function Compile([string]$ToolName, [string[]]$Arguments) {
    & $Java '-Xmx768m' '-Dsun.io.useCanonCaches=false' '-Djava.util.Arrays.useLegacyMergeSort=true' '-jar' (Join-Path $flexRoot "lib\$ToolName.jar") "+flexlib=$flexRoot\frameworks" @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$ToolName failed ($LASTEXITCODE)" }
}
if (!$TestsOnly) {
$stubSwc = Join-Path $out 'host-signatures.swc'
$stubConfig = Write-Config 'stubs' @((Join-Path $PSScriptRoot 'stubs')) @($airSwc)
Compile 'compc' @("-load-config=$stubConfig", '-include-classes=fe.unit.Unit,fe.weapon.Bullet,fe.loc.Box,fe.loc.Tile', "-output=$stubSwc")
$config = Write-Config 'candidate' @($SourceDirectory) @($airSwc, $stubSwc)
Compile 'mxmlc' @("-load-config=$config", '-swf-version=32', '-use-network=false', '-static-link-runtime-shared-libraries=true', '-includes=lad.native.LadLampTarget', "-output=$out\LightAndDarknessMod.swf", "$SourceDirectory\LightAndDarknessDoc.as")
}
if ($Tests -or $TestsOnly) {
    $testConfig = Write-Config 'tests' @((Join-Path $modRoot 'tests')) @($airSwc)
    Compile 'mxmlc' @("-load-config=$testConfig", '-swf-version=32', '-use-network=false', '-static-link-runtime-shared-libraries=true', "-output=$out\LightAndDarknessTest.swf", "$modRoot\tests\LightAndDarknessTest.as")
}
$artifact = Join-Path $out 'LightAndDarknessMod.swf'
$hashStream = [IO.File]::OpenRead($artifact)
$hasher = [Security.Cryptography.SHA256]::Create()
try { [pscustomobject]@{Path=$artifact;Hash=([BitConverter]::ToString($hasher.ComputeHash($hashStream))).Replace('-','')} }
finally { $hashStream.Dispose();$hasher.Dispose() }
