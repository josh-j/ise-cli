[CmdletBinding()]
param(
    [string] $RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string] $OutputRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'out')
)

$ErrorActionPreference = 'Stop'
$manifestPath = Join-Path $RepositoryRoot 'src/Ise.Cli/Ise.Cli.psd1'
$manifest = Import-PowerShellDataFile -Path $manifestPath
$target = Join-Path $OutputRoot "Ise.Cli/$($manifest.ModuleVersion)"

if (Test-Path -LiteralPath $target) {
    Remove-Item -LiteralPath $target -Recurse -Force
}
$null = New-Item -ItemType Directory -Path $target -Force
$null = New-Item -ItemType Directory -Path (Join-Path $target 'Core') -Force
$null = New-Item -ItemType Directory -Path (Join-Path $target 'Rest') -Force
$null = New-Item -ItemType Directory -Path (Join-Path $target 'DataConnect') -Force
$null = New-Item -ItemType Directory -Path (Join-Path $target 'PxGrid') -Force
$null = New-Item -ItemType Directory -Path (Join-Path $target 'Features') -Force
$null = New-Item -ItemType Directory -Path (Join-Path $target 'schemas') -Force

Copy-Item -Path (Join-Path $RepositoryRoot 'src/Ise.Cli/*') -Destination $target -Recurse -Force
Copy-Item -Path (Join-Path $RepositoryRoot 'src/Ise.Cli.Core/*') `
    -Destination (Join-Path $target 'Core') -Recurse -Force
Copy-Item -Path (Join-Path $RepositoryRoot 'src/Ise.Cli.Rest/*') `
    -Destination (Join-Path $target 'Rest') -Recurse -Force
Copy-Item -Path (Join-Path $RepositoryRoot 'src/Ise.Cli.DataConnect/*') `
    -Destination (Join-Path $target 'DataConnect') -Recurse -Force
Copy-Item -Path (Join-Path $RepositoryRoot 'src/Ise.Cli.PxGrid/*') `
    -Destination (Join-Path $target 'PxGrid') -Recurse -Force
Copy-Item -Path (Join-Path $RepositoryRoot 'src/Ise.Cli.Features/*') `
    -Destination (Join-Path $target 'Features') -Recurse -Force
Copy-Item -Path (Join-Path $RepositoryRoot 'schemas/*') `
    -Destination (Join-Path $target 'schemas') -Recurse -Force

$target
