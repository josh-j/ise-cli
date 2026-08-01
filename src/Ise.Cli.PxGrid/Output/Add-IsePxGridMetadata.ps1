function Add-IsePxGridMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] $InputObject,
        [Parameter(Mandatory)] $Descriptor,
        [Parameter(Mandatory)] [string] $Operation,
        $Correlation
    )
    process {
        $suffix = ($Descriptor.Name, $Operation | ForEach-Object {
            [regex]::Replace([string]$_, '[^A-Za-z0-9]', '')
        }) -join '.'
        $InputObject.PSObject.TypeNames.Insert(0, "Ise.PxGrid.$suffix")
        $metadata = [pscustomobject]@{
            Datasource = 'PxGrid'; Service = $Descriptor.Service
            NodeName = $Descriptor.NodeName; Operation = $Operation
            CorrelationId = $Correlation.CorrelationId
        }
        $name = if ($InputObject.PSObject.Properties.Name -contains 'IseMetadata') {
            'IseCliMetadata'
        } else { 'IseMetadata' }
        Add-Member -InputObject $InputObject -MemberType NoteProperty -Name $name `
            -Value $metadata -Force
        $InputObject
    }
}
