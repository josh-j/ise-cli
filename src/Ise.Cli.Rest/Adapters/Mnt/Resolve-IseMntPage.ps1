function Resolve-IseMntPage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Response,
        [Parameter(Mandatory)] $Descriptor,
        [Parameter(Mandatory)] [int] $Page
    )

    $body = $Response.BodyObject
    if ($body -isnot [xml]) {
        return [pscustomobject]@{ Items = @($body); NextPath = $null; Total = $null }
    }
    $root = $body.DocumentElement
    $nodes = @($root.ChildNodes | Where-Object { $_.NodeType -eq 'Element' })
    $records = foreach ($node in $nodes) {
        $record = [ordered]@{}
        foreach ($child in @($node.ChildNodes | Where-Object { $_.NodeType -eq 'Element' })) {
            $name = ($child.LocalName -creplace '([a-z0-9])([A-Z])', '$1_$2').ToLowerInvariant()
            $record[$name] = $child.InnerText
        }
        if ($record.Count) { [pscustomobject]$record }
    }
    if (-not $records) {
        $record = [ordered]@{}
        foreach ($child in $nodes) {
            $name = ($child.LocalName -creplace '([a-z0-9])([A-Z])', '$1_$2').ToLowerInvariant()
            $record[$name] = $child.InnerText
        }
        if ($record.Count) { $records = @([pscustomobject]$record) }
    }
    [pscustomobject]@{ Items = @($records); NextPath = $null; Total = $null }
}
