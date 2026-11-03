# Append a single record to a manifest JSONL file

Atomically publish one completion record.

## Usage

``` r
.manifest_append(path, record)
```

## Arguments

- path:

  Path to the JSONL file.

- record:

  A list to serialize as one JSON line.

## Details

Each record is written to a unique temporary file and renamed within its
stage directory. This avoids shared append races and retains legacy
JSONL files as read-only input for backwards compatibility.
