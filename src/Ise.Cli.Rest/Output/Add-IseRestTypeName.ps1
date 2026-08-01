function Add-IseRestTypeName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] $InputObject,
        [Parameter(Mandatory)] [string] $TypeName
    )
    process {
        if ($null -ne $InputObject -and $InputObject.PSObject.TypeNames[0] -ne $TypeName) {
            $InputObject.PSObject.TypeNames.Insert(0, $TypeName)
        }
        $InputObject
    }
}
