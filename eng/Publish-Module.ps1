[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory)] [string] $Repository,
    [securestring] $ApiKey
)

$ErrorActionPreference = 'Stop'
$modulePath = & (Join-Path $RepositoryRoot 'eng/Build-Module.ps1') `
    -RepositoryRoot $RepositoryRoot
$arguments = @{
    Path       = $modulePath
    Repository = $Repository
}
if ($ApiKey) { $arguments.ApiKey = $ApiKey }
if ($PSCmdlet.ShouldProcess($Repository, "Publish Ise.Cli from $modulePath")) {
    Publish-PSResource @arguments
}
