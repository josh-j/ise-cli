# 0009: Add semantic providers only after real adapters

## Status

Accepted

## Decision

REST, Data Connect, and pxGrid retain protocol-native commands and objects. Once
those independently bounded adapters existed, Core gained a small semantic
provider registry. Feature commands request capabilities through that registry
and never construct HTTP requests, SQL, or subscriptions.

## Consequences

Features can combine multiple sources without protocol branches. Providers can
fail independently and their native records and errors remain available as
evidence. The registry is validated by contract tests and stays internal until
a public extension use case is proven.
