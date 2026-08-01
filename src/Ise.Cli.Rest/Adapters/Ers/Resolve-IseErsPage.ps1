function Resolve-IseErsPage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Response,
        [Parameter(Mandatory)] $Descriptor,
        [Parameter(Mandatory)] [int] $Page
    )

    $body = $Response.BodyObject
    if ($null -eq $body) {
        throw [IseSerializationException]::new(
            'ERS returned an empty response.',
            @{ Datasource = 'Rest.Ers'; Operation = 'Enumerate'; Target = $Descriptor.Name
               Uri = $Response.RequestUri.AbsoluteUri; RequestId = $Response.RequestId; Page = $Page }
        )
    }
    if ($body.PSObject.Properties.Name -notcontains 'SearchResult') {
        return [pscustomobject]@{ Items = @($body); NextPath = $null; Total = 1 }
    }
    $result = $body.SearchResult
    if ($null -eq $result) {
        throw [IseSerializationException]::new(
            'ERS SearchResult was null.',
            @{ Datasource = 'Rest.Ers'; Operation = 'Enumerate'; Target = $Descriptor.Name
               Uri = $Response.RequestUri.AbsoluteUri; RequestId = $Response.RequestId; Page = $Page }
        )
    }
    $items = if ($result.PSObject.Properties.Name -contains 'resources') {
        @($result.resources)
    } else { @() }
    $next = $null
    if ($result.PSObject.Properties.Name -contains 'nextPage' -and $result.nextPage) {
        $next = [string]$result.nextPage.href
    }
    if (-not $next -and $result.PSObject.Properties.Name -contains '_links' -and
        $result._links -and $result._links.next) {
        $next = if ($result._links.next -is [string]) {
            [string]$result._links.next
        } else { [string]$result._links.next.href }
    }
    [pscustomobject]@{
        Items    = $items
        NextPath = $next
        Total    = if ($result.PSObject.Properties.Name -contains 'total') { $result.total } else { $null }
    }
}
