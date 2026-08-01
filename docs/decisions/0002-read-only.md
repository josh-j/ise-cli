# ADR 0002: The product is read-only

Status: accepted

Public datasource operations retrieve, query, snapshot, or subscribe to data.
The module does not expose ISE configuration mutation, deletion, CoA, or
arbitrary HTTP methods.
