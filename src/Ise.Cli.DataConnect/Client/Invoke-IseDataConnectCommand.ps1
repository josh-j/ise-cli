function Invoke-IseDataConnectCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [IseSession] $Session,
        [Parameter(Mandatory)] [string] $Sql,
        [hashtable] $Parameters,
        [ValidateSet('Catalog', 'Query')] [string] $Operation = 'Query',
        [string] $Target,
        [int] $First,
        $Correlation
    )

    $requestId = [guid]::NewGuid().ToString('N')
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $null = Write-IseLogEvent -Level Debug -EventId 'dataconnect.query.started' `
        -Message "Data Connect $Operation started for $Target." -Correlation $Correlation `
        -RequestId $requestId -Datasource DataConnect -Operation $Operation -Target $Target
    try {
        $count = 0
        if ($Session.DatasourceState.ContainsKey('DataConnect.Executor')) {
            $executor = $Session.DatasourceState['DataConnect.Executor']
            & $executor -Operation $Operation -Sql $Sql -Parameters $Parameters -Target $Target -First $First |
                ForEach-Object {
                    if ($First -le 0 -or $count -lt $First) {
                        $_
                        $count++
                    }
                }
        }
        else {
            $connection = Open-IseDataConnectConnection -Session $Session -Correlation $Correlation
            $command = $connection.CreateCommand()
            $command.CommandText = $Sql
            if ($Parameters) {
                foreach ($name in @($Parameters.Keys)) {
                    $parameter = $command.CreateParameter()
                    $parameter.ParameterName = [string]$name
                    $parameter.Value = if ($null -eq $Parameters[$name]) { [DBNull]::Value } else { $Parameters[$name] }
                    $null = $command.Parameters.Add($parameter)
                }
            }
            $reader = $command.ExecuteReader()
            try {
                while ($reader.Read()) {
                    $row = [ordered]@{}
                    for ($index = 0; $index -lt $reader.FieldCount; $index++) {
                        $value = $reader.GetValue($index)
                        $row[$reader.GetName($index)] = if ($value -is [DBNull]) { $null } else { $value }
                    }
                    [pscustomobject]$row
                    $count++
                    if ($First -gt 0 -and $count -ge $First) { break }
                }
            }
            finally {
                $reader.Dispose()
                $command.Dispose()
            }
        }
        $null = Write-IseLogEvent -Level Information -EventId 'dataconnect.query.completed' `
            -Message "Data Connect $Operation completed for $Target with $count rows." `
            -Correlation $Correlation -RequestId $requestId -Datasource DataConnect `
            -Operation $Operation -Target $Target -DurationMilliseconds $timer.Elapsed.TotalMilliseconds `
            -RecordCount $count
    }
    catch [System.Management.Automation.PipelineStoppedException] { throw }
    catch [IseDataConnectException] { throw }
    catch {
        throw [IseDataConnectException]::new(
            "Data Connect $Operation failed for ${Target}: $($_.Exception.Message)",
            @{ Datasource = 'DataConnect'; Operation = $Operation; Target = $Target
               CorrelationId = $Correlation.CorrelationId; RequestId = $requestId },
            $_.Exception
        )
    }
    finally { $timer.Stop() }
}
