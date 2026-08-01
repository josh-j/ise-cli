[CmdletBinding()]
param(
    [string] $RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string] $BuiltModulePath,
    [string] $DestinationRoot,
    [switch] $Force
)

$ErrorActionPreference = 'Stop'
if (-not $BuiltModulePath) {
    $BuiltModulePath = & (Join-Path $RepositoryRoot 'eng/Build-Module.ps1') `
        -RepositoryRoot $RepositoryRoot
}
$manifestPath = Join-Path $BuiltModulePath 'Ise.Cli.psd1'
$manifest = Import-PowerShellDataFile -Path $manifestPath

if (-not $DestinationRoot) {
    $userProfile = [Environment]::GetFolderPath(
        [Environment+SpecialFolder]::UserProfile
    )
    $DestinationRoot = $env:PSModulePath -split [IO.Path]::PathSeparator |
        Where-Object { $_ -and $_.StartsWith($userProfile, [StringComparison]::Ordinal) } |
        Select-Object -First 1
    if (-not $DestinationRoot) {
        throw 'No user-scoped PSModulePath entry was found. Supply -DestinationRoot explicitly.'
    }
}

$destination = Join-Path $DestinationRoot "Ise.Cli/$($manifest.ModuleVersion)"
if (Test-Path -LiteralPath $destination) {
    if (-not $Force) {
        throw "Ise.Cli $($manifest.ModuleVersion) is already installed at '$destination'. Use -Force to replace it."
    }
    Remove-Item -LiteralPath $destination -Recurse -Force
}

$null = New-Item -ItemType Directory -Path $destination -Force
Copy-Item -Path (Join-Path $BuiltModulePath '*') -Destination $destination -Recurse -Force
$destination
