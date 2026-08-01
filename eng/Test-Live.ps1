[CmdletBinding()]
param([string] $RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$required = @('ISE_TEST_SERVER', 'ISE_TEST_USERNAME', 'ISE_TEST_PASSWORD')
$missing = @($required | Where-Object {
    [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_))
})
if ($missing) {
    throw "Live ISE validation requires: $($missing -join ', ')."
}

& (Join-Path $RepositoryRoot 'eng/Test-Module.ps1') `
    -RepositoryRoot $RepositoryRoot -IncludeLive
