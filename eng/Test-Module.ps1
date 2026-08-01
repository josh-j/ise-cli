[CmdletBinding()]
param(
    [string] $RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [switch] $IncludeLive
)

$ErrorActionPreference = 'Stop'
$analyzer = Get-Module -ListAvailable PSScriptAnalyzer |
    Sort-Object Version -Descending | Select-Object -First 1
if (-not $analyzer) {
    throw 'PSScriptAnalyzer is required. Install-PSResource PSScriptAnalyzer -Scope CurrentUser'
}
Import-Module $analyzer.Path -Force
$analysis = @(Invoke-ScriptAnalyzer -Path (Join-Path $RepositoryRoot 'src') -Recurse `
    -Settings (Join-Path $RepositoryRoot 'PSScriptAnalyzerSettings.psd1'))
if ($analysis) {
    $analysis | Format-Table RuleName, Severity, ScriptName, Line, Message -AutoSize | Out-String | Write-Error
}

$builtPath = & (Join-Path $RepositoryRoot 'eng/Build-Module.ps1') -RepositoryRoot $RepositoryRoot
$env:ISE_CLI_BUILT_MODULE = Join-Path $builtPath 'Ise.Cli.psd1'
$pester = Get-Module -ListAvailable Pester | Where-Object Version -ge ([version]'5.0.0') |
    Sort-Object Version -Descending | Select-Object -First 1
if (-not $pester) {
    throw 'Pester 5 is required. Install-PSResource Pester -Scope CurrentUser'
}
Import-Module $pester.Path -Force
$paths = @(
    (Join-Path $RepositoryRoot 'tests/Core')
    (Join-Path $RepositoryRoot 'tests/Contracts')
    (Join-Path $RepositoryRoot 'tests/Rest')
    (Join-Path $RepositoryRoot 'tests/DataConnect')
    (Join-Path $RepositoryRoot 'tests/PxGrid')
    (Join-Path $RepositoryRoot 'tests/Features')
    (Join-Path $RepositoryRoot 'tests/Integration')
)
if ($IncludeLive) { $paths += Join-Path $RepositoryRoot 'tests/Live' }
$configuration = New-PesterConfiguration
$configuration.Run.Path = $paths
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Detailed'
$configuration.TestResult.Enabled = $true
$configuration.TestResult.OutputPath = Join-Path $RepositoryRoot 'out/test-results.xml'
$result = Invoke-Pester -Configuration $configuration
if ($result.FailedCount -gt 0) { throw "$($result.FailedCount) Pester tests failed." }
if ($IsLinux) {
    $null = & (Join-Path $RepositoryRoot 'eng/Test-LinuxInstall.ps1') `
        -RepositoryRoot $RepositoryRoot -BuiltModulePath $builtPath
}
$result
