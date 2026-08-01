function Invoke-IseSemanticCapability {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Capability,
        [hashtable] $Filter,
        [Parameter(Mandatory)] $Correlation
    )

    $session = Assert-IseConnected -Correlation $Correlation
    $providers = @(Get-IseSemanticProvider -Capability $Capability)
    if (-not $providers) {
        [pscustomobject]@{
            PSTypeName = 'Ise.SemanticEvidence'; Capability = $Capability
            Provider = $null; Source = $null; Available = $false; Succeeded = $false
            Records = @(); Error = $null; Reason = 'No provider is registered.'
            DurationMilliseconds = $null
        }
        return
    }
    foreach ($provider in $providers) {
        $available = $true
        $reason = $null
        if ($provider.Test) {
            try { $available = [bool](& $provider.Test -Session $session -Provider $provider) }
            catch { $available = $false; $reason = $_.Exception.Message }
        }
        if (-not $available) {
            [pscustomobject]@{
                PSTypeName = 'Ise.SemanticEvidence'; Capability = $Capability
                Provider = $provider.Name; Source = $provider.Source
                Available = $false; Succeeded = $false; Records = @()
                Error = $null; Reason = if ($reason) { $reason } else { 'Provider is not configured.' }
                DurationMilliseconds = $null
            }
            continue
        }
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $records = @(& $provider.Invoke -Session $session -Filter $Filter `
                -Correlation $Correlation -Provider $provider)
            [pscustomobject]@{
                PSTypeName = 'Ise.SemanticEvidence'; Capability = $Capability
                Provider = $provider.Name; Source = $provider.Source
                Available = $true; Succeeded = $true; Records = $records
                Error = $null; Reason = $null
                DurationMilliseconds = $timer.Elapsed.TotalMilliseconds
            }
        }
        catch [System.Management.Automation.PipelineStoppedException] { throw }
        catch {
            $null = Write-IseLogEvent -Level Warning -EventId 'semantic.provider.failed' `
                -Message "Semantic provider '$($provider.Name)' failed." `
                -Correlation $Correlation -Datasource $provider.Source `
                -Operation $Capability -Target $provider.Name -Exception $_.Exception
            [pscustomobject]@{
                PSTypeName = 'Ise.SemanticEvidence'; Capability = $Capability
                Provider = $provider.Name; Source = $provider.Source
                Available = $true; Succeeded = $false; Records = @()
                Error = $_; Reason = $_.Exception.Message
                DurationMilliseconds = $timer.Elapsed.TotalMilliseconds
            }
        }
        finally { $timer.Stop() }
    }
}
