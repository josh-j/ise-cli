function Read-IsePxGridSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [Parameter(Mandatory)] $Descriptor,
        [Parameter(Mandatory)] [string] $Path,
        [hashtable] $Body,
        [int] $First,
        [switch] $Raw,
        $Correlation
    )

    if ([string]::IsNullOrWhiteSpace([string]$Descriptor.RestBaseUrl) -and
        -not [uri]::IsWellFormedUriString($Path, [System.UriKind]::Absolute)) {
        throw [IsePxGridException]::new(
            "pxGrid service '$($Descriptor.Service)' advertised no REST base URL.",
            @{ Datasource = 'PxGrid'; Operation = 'Snapshot'; Target = $Descriptor.Service }
        )
    }
    $uri = if ([uri]::IsWellFormedUriString($Path, [System.UriKind]::Absolute)) {
        [uri]$Path
    } else {
        $base = [uri]([string]$Descriptor.RestBaseUrl).TrimEnd('/')
        [uri]::new([uri]($base.AbsoluteUri + '/'), $Path.TrimStart('/'))
    }
    $response = Invoke-IsePxGridRequest -Session $Session -Operation Snapshot -Uri $uri `
        -Body $Body -PeerNodeName $Descriptor.NodeName -Target $Descriptor.Service `
        -Correlation $Correlation
    if ($Raw) { return $response }
    $items = if ($response -is [System.Collections.IEnumerable] -and $response -isnot [string] -and
        $response -isnot [pscustomobject]) {
        @($response)
    } else {
        $arrayProperty = @($response.PSObject.Properties | Where-Object {
            $_.Value -is [System.Collections.IEnumerable] -and $_.Value -isnot [string] -and
            $_.Name -notin @('IseMetadata', 'IseCliMetadata')
        } | Select-Object -First 1)
        if ($arrayProperty) { @($arrayProperty[0].Value) } else { @($response) }
    }
    $count = 0
    foreach ($item in $items) {
        if ($null -eq $item) { continue }
        $item | Add-IsePxGridMetadata -Descriptor $Descriptor -Operation $Path `
            -Correlation $Correlation
        $count++
        if ($First -gt 0 -and $count -ge $First) { break }
    }
}
