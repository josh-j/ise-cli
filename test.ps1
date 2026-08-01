[CmdletBinding()]
param([switch] $IncludeLive)

& (Join-Path $PSScriptRoot 'eng/Test-Module.ps1') -IncludeLive:$IncludeLive
