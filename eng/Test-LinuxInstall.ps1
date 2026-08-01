[CmdletBinding()]
param(
    [string] $RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string] $BuiltModulePath
)

$ErrorActionPreference = 'Stop'
if (-not $IsLinux) { return }

if (-not $BuiltModulePath) {
    $BuiltModulePath = & (Join-Path $RepositoryRoot 'eng/Build-Module.ps1') `
        -RepositoryRoot $RepositoryRoot
}
$manifest = Import-PowerShellDataFile -Path (Join-Path $BuiltModulePath 'Ise.Cli.psd1')
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) `
    "ise-cli-linux-$([guid]::NewGuid().ToString('N'))"
$moduleBase = Join-Path $temporaryRoot 'Modules'
$installedPath = Join-Path $moduleBase "Ise.Cli/$($manifest.ModuleVersion)"
$server = $null

try {
    $actualInstalledPath = & (Join-Path $RepositoryRoot 'eng/Install-IseCli.ps1') `
        -RepositoryRoot $RepositoryRoot -BuiltModulePath $BuiltModulePath `
        -DestinationRoot $moduleBase
    if ($actualInstalledPath -ne $installedPath) {
        throw "Linux install path was '$actualInstalledPath'; expected '$installedPath'."
    }

    . (Join-Path $RepositoryRoot 'tests/TestSupport/Start-FakeIseServer.ps1')
    . (Join-Path $RepositoryRoot 'tests/TestSupport/Stop-FakeIseServer.ps1')
    $routes = @{
        '/ers/config/endpoint' = @{ Body = @{
            SearchResult = @{
                total = 2
                resources = @([ordered]@{ id = 'linux-1'; name = 'linux-endpoint-1' })
                nextPage = @{ href = '/ers/config/endpoint?page=2' }
            }
        } | ConvertTo-Json -Depth 8 -Compress }
        '/ers/config/endpoint?page=2' = @{ Body = @{
            SearchResult = @{
                total = 2
                resources = @([ordered]@{ id = 'linux-2'; name = 'linux-endpoint-2' })
            }
        } | ConvertTo-Json -Depth 8 -Compress }
    }
    $server = Start-FakeIseServer -Routes $routes

    $moduleBaseLiteral = $moduleBase.Replace("'", "''")
    $serverLiteral = $server.Uri.AbsoluteUri.Replace("'", "''")
    $smokeTest = @"
`$ErrorActionPreference = 'Stop'
`$env:PSModulePath = '$moduleBaseLiteral' + [IO.Path]::PathSeparator + `$env:PSModulePath
Set-Location '$($temporaryRoot.Replace("'", "''"))'
Import-Module Ise.Cli -Force -ErrorAction Stop
`$commands = @(Get-Command -Module Ise.Cli)
if (`$commands.Count -ne 13) { throw "Expected 13 exported commands, found `$(`$commands.Count)." }
`$credential = [pscredential]::new(
    'linux-test',
    (ConvertTo-SecureString 'linux-test' -AsPlainText -Force)
)
Connect-Ise -Server '$serverLiteral' -Credential `$credential -InformationAction SilentlyContinue | Out-Null
`$rows = @(Get-IseRest -Ers Endpoint -InformationAction SilentlyContinue)
if (`$rows.Count -ne 2) { throw "Expected two ERS records, found `$(`$rows.Count)." }
if (`$rows[0].PSObject.TypeNames[0] -ne 'Ise.Rest.Ers.Endpoint') {
    throw "Linux output type name was `$(`$rows[0].PSObject.TypeNames[0])."
}
if (`$rows.id -join ',' -ne 'linux-1,linux-2') { throw 'Linux pagination order was incorrect.' }
Disconnect-Ise -InformationAction SilentlyContinue
[pscustomobject]@{
    Platform = 'Linux'
    PowerShell = `$PSVersionTable.PSVersion.ToString()
    ModuleVersion = (Get-Module Ise.Cli).Version.ToString()
    ExportedCommands = `$commands.Count
    Records = `$rows.Count
    InstallRoot = '$moduleBaseLiteral'
}
"@
    $powerShell = (Get-Process -Id $PID).Path
    $result = & $powerShell -NoLogo -NoProfile -Command $smokeTest
    if ($LASTEXITCODE -ne 0) {
        throw "The clean-install Linux smoke process exited with code $LASTEXITCODE."
    }
    $result
}
finally {
    if ($server) { Stop-FakeIseServer $server }
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
