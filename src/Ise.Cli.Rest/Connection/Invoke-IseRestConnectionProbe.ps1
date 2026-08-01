function Invoke-IseRestConnectionProbe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [Parameter(Mandatory)] [string] $Source,
        [Parameter(Mandatory)] [string] $Path,
        [hashtable] $Query,
        [string] $Accept = 'application/json',
        [switch] $DetectVersion,
        $Correlation
    )

    try {
        $response = Send-IseRestRequest -Session $Session -Path $Path -Query $Query `
            -Correlation $Correlation -Datasource $Source -Operation Connect -Target Probe `
            -Accept $Accept
        $Session.Capabilities[$Source] = $true
        $Session.DatasourceState['Connection.HttpReachable'] = $true
        $Session.DatasourceState["Connection.Probe.$Source"] = [pscustomobject]@{
            Available = $true; StatusCode = $response.StatusCode; Error = $null
        }
        if ($DetectVersion -and -not $Session.ServerVersion) {
            $version = Get-IseVersionFromProbe -InputObject $response.BodyObject
            if ($version) { $Session.ServerVersion = $version }
        }
        $null = Write-IseLogEvent -Level Information -EventId 'schema.discovery.completed' `
            -Message "$Source connection probe succeeded." -Correlation $Correlation `
            -Datasource $Source -Operation Connect -Target Probe `
            -StatusCode $response.StatusCode
    }
    catch [IseAuthenticationException] { throw }
    catch [IseCertificateException] { throw }
    catch [IseConnectionException] { throw }
    catch [IseHttpException] {
        $Session.DatasourceState['Connection.HttpReachable'] = $true
        $Session.Capabilities[$Source] = $false
        $status = if ($_.Exception.Context.ContainsKey('StatusCode')) {
            [int]$_.Exception.Context['StatusCode']
        } else { 0 }
        $Session.DatasourceState["Connection.Probe.$Source"] = [pscustomobject]@{
            Available = $false; StatusCode = $status; Error = $_.Exception
        }
        $null = Write-IseLogEvent -Level Debug -EventId 'schema.discovery.failed' `
            -Message "$Source connection probe returned HTTP $status." `
            -Correlation $Correlation -Datasource $Source -Operation Connect `
            -Target Probe -StatusCode $status -Exception $_.Exception
    }
    catch [IseSerializationException] {
        $Session.DatasourceState['Connection.HttpReachable'] = $true
        $Session.Capabilities[$Source] = $false
        $Session.DatasourceState["Connection.Probe.$Source"] = [pscustomobject]@{
            Available = $false; StatusCode = 200; Error = $_.Exception
        }
        $null = Write-IseLogEvent -Level Debug -EventId 'schema.discovery.failed' `
            -Message "$Source connection probe returned an unsupported payload." `
            -Correlation $Correlation -Datasource $Source -Operation Connect `
            -Target Probe -StatusCode 200 -Exception $_.Exception
    }
}
