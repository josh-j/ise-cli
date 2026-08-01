function New-TestCredential {
    [CmdletBinding()]
    param(
        [string] $UserName = 'test-user',
        [string] $Password = 'test-password'
    )
    [pscredential]::new(
        $UserName,
        (ConvertTo-SecureString $Password -AsPlainText -Force)
    )
}
