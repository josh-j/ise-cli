function Add-IseMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] $InputObject,
        [Parameter(Mandatory)] [hashtable] $Metadata
    )
    process {
        $name = if ($InputObject.PSObject.Properties.Name -contains 'IseMetadata') {
            'IseCliMetadata'
        } else { 'IseMetadata' }
        Add-Member -InputObject $InputObject -MemberType NoteProperty -Name $name `
            -Value ([pscustomobject]$Metadata) -Force
        $InputObject
    }
}
