function New-IseResourceDescriptor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Api,
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $CollectionPath,
        [string] $DetailPathTemplate,
        [bool] $CanEnumerate = $true,
        [bool] $CanGetById = $false,
        [string] $PaginationStrategy = 'Single',
        [string] $CollectionEnvelope,
        [string] $ItemTypeName,
        [ValidateSet('Live', 'Bundled', 'Caller')]
        [string] $SchemaSource = 'Bundled',
        [string[]] $RequiredParameters = @()
    )

    [pscustomobject]@{
        PSTypeName         = 'Ise.Rest.ResourceDescriptor'
        Api                = $Api
        Name               = $Name
        CollectionPath     = $CollectionPath
        DetailPathTemplate = $DetailPathTemplate
        CanEnumerate       = $CanEnumerate
        CanGetById         = $CanGetById
        PaginationStrategy = $PaginationStrategy
        CollectionEnvelope = $CollectionEnvelope
        ItemTypeName       = if ($ItemTypeName) { $ItemTypeName } else { "Ise.Rest.$Api.$Name" }
        SchemaSource       = $SchemaSource
        RequiredParameters = @($RequiredParameters)
    }
}
