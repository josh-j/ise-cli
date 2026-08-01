# ADR 0003: One active connection

Status: accepted

One module-private ISE session is active at a time. Connecting again disposes
the previous session. A future requirement may revisit multiple concurrent
deployments without changing datasource operation contracts.
