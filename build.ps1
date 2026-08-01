[CmdletBinding()]
param([string] $OutputRoot)

$arguments = @{}
if ($OutputRoot) { $arguments.OutputRoot = $OutputRoot }
& (Join-Path $PSScriptRoot 'eng/Build-Module.ps1') @arguments
