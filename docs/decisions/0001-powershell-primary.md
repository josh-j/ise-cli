# ADR 0001: PowerShell is the primary interface

Status: accepted

ISE CLI is delivered as a PowerShell 7.4+ module. Linux is its primary,
release-blocking runtime; Windows PowerShell 7 is a compatibility target.
Commands emit objects, honor PowerShell streams and common parameters, and
compose through the pipeline. Implementation code uses cross-platform .NET and
PowerShell APIs and must not rely on Windows PowerShell, the desktop CLR, the
registry, WinRM, or fixed platform-specific paths.
