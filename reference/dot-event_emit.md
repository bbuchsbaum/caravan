# Emit a structured event to the run's event log

Appends a single JSONL line on a best-effort basis. Concurrent writes to
a shared file are not guaranteed to be atomic on all filesystems,
including NFS. Logging errors do not fail the pipeline.

## Usage

``` r
.event_emit(run_id, event_type, severity = "info", source = "parade", ...)
```

## Arguments

- run_id:

  Character run identifier

- event_type:

  One of the event taxonomy types

- severity:

  "info", "warn", or "error"

- source:

  Component emitting the event (e.g., "submit", "chunk", "stage")

- ...:

  Additional named fields to include in the event

## Value

NULL (invisible), called for side effect
