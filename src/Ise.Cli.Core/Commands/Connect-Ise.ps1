function Connect-Ise {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [uri] $Server,
        [Parameter(Mandatory)] [pscredential] $Credential,
        [switch] $SkipCertificateCheck,
        [ValidateRange(1, 86400)] [int] $TimeoutSec = 100
    )

    dynamicparam { New-IseConnectionDynamicParameters }

    end {
        $correlation = New-IseCorrelationContext -Command $MyInvocation.MyCommand.Name
        $null = Write-IseLogEvent -Level Information -EventId 'connection.opening' `
            -Message "Opening ISE connection to $Server." -Correlation $correlation `
            -Operation 'Connect' -Target $Server.AbsoluteUri
        try {
            if ($script:IseSession) { Close-IseSession -Session $script:IseSession }
            $script:IseSession = New-IseSession -Server $Server -Credential $Credential `
                -SkipCertificateCheck:$SkipCertificateCheck -TimeoutSec $TimeoutSec
            Initialize-IseDataSourceConfiguration -Session $script:IseSession `
                -BoundParameters $PSBoundParameters -Correlation $correlation
            foreach ($descriptor in @($script:IseDataSources.Values)) {
                if (-not $descriptor.Open) { continue }
                $null = & $descriptor.Open -Session $script:IseSession -Correlation $correlation
            }
            $null = Write-IseLogEvent -Level Information -EventId 'connection.opened' `
                -Message "ISE connection opened to $($script:IseSession.ServerUri)." `
                -Correlation $correlation -Operation 'Connect' `
                -Target $script:IseSession.ServerUri.AbsoluteUri
            Get-IseConnection
        }
        catch {
            if ($script:IseSession) {
                Close-IseSession -Session $script:IseSession
                $script:IseSession = $null
            }
            $exception = if ($_.Exception -is [IseException]) {
                $_.Exception
            } else {
                [IseConnectionException]::new(
                    "Could not connect to ISE at ${Server}: $($_.Exception.Message)",
                    @{ Operation = 'Connect'; Target = $Server.AbsoluteUri
                       CorrelationId = $correlation.CorrelationId },
                    $_.Exception
                )
            }
            $null = Write-IseLogEvent -Level Error -EventId 'connection.failed' `
                -Message $exception.Message -Correlation $correlation -Operation 'Connect' `
                -Target $Server.AbsoluteUri -Exception $exception
            $PSCmdlet.ThrowTerminatingError((ConvertTo-IseErrorRecord -Exception $exception))
        }
    }
}
