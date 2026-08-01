function Merge-IseResourceCatalog {
    [CmdletBinding()]
    param(
        [object[]] $Live,
        [object[]] $Bundled
    )

    $merged = [ordered]@{}
    foreach ($descriptor in @($Bundled)) { $merged[[string]$descriptor.Name] = $descriptor }
    foreach ($descriptor in @($Live)) { $merged[[string]$descriptor.Name] = $descriptor }
    @($merged.Values)
}
