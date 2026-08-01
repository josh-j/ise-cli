function Open-TestIseSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [pscredential] $Credential,
        [uri] $Server = 'https://ise.example.test'
    )

    $module = Get-Module Ise.Cli
    if (-not $module) { throw 'Ise.Cli must be imported before opening a test session.' }
    & $module {
        param($TestCredential, $TestServer)
        if ($script:IseSession) { Close-IseSession -Session $script:IseSession }
        $script:IseSession = New-IseSession -Server $TestServer -Credential $TestCredential
    } $Credential $Server
}
