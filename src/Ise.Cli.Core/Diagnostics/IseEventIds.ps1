$script:IseEventIds = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::Ordinal
)
foreach ($eventId in @(
    'command.started', 'command.completed', 'command.failed',
    'connection.opening', 'connection.opened', 'connection.failed', 'connection.closed',
    'source.operation.started', 'source.operation.completed', 'source.operation.failed',
    'rest.request.started', 'rest.request.completed', 'rest.request.failed',
    'rest.page.completed', 'rest.pagination.completed', 'rest.resource.failed',
    'schema.discovery.completed', 'schema.discovery.failed', 'pipeline.cancelled',
    'dataconnect.connection.opened', 'dataconnect.query.started', 'dataconnect.query.completed',
    'pxgrid.account.activated', 'pxgrid.discovery.completed', 'pxgrid.request.started',
    'pxgrid.request.completed', 'pxgrid.service.unavailable',
    'pxgrid.subscription.started', 'pxgrid.subscription.connected',
    'pxgrid.subscription.completed', 'pxgrid.subscription.failed',
    'pxgrid.subscription.reconnecting', 'semantic.provider.failed',
    'feature.context.started', 'feature.context.completed'
)) { $null = $script:IseEventIds.Add($eventId) }
