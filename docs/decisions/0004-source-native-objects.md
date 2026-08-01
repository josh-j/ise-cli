# ADR 0004: Preserve source-native objects

Status: accepted

Adapters unwrap transport envelopes but do not rename or discard source fields.
They add a source-specific PowerShell type name and provenance metadata.
Normalization belongs to future feature commands.
