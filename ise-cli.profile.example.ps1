# Copy this file to ise-cli.profile.ps1 and restrict it to your user account.
# The local filename is gitignored because the passwords below are plaintext.

function New-IseProfileCredential {
    param(
        [Parameter(Mandatory)] [string] $UserName,
        [Parameter(Mandatory)] [string] $Password
    )
    [pscredential]::new(
        $UserName,
        (ConvertTo-SecureString $Password -AsPlainText -Force)
    )
}

$ersCredential = New-IseProfileCredential '<ers-username>' '<ers-password>'
$mntCredential = New-IseProfileCredential '<mnt-username>' '<mnt-password>'
$openApiCredential = New-IseProfileCredential '<openapi-username>' '<openapi-password>'
$dataConnectCredential = New-IseProfileCredential '<dataconnect-username>' '<dataconnect-password>'

$connection = @{
    Server                      = 'https://ise.example.net'
    Credential                  = $ersCredential
    ErsCredential               = $ersCredential
    MntCredential               = $mntCredential
    OpenApiCredential           = $openApiCredential
    DataConnectConnectionString = 'Data Source=ise-reporting'
    DataConnectCredential       = $dataConnectCredential
}

Connect-Ise @connection
