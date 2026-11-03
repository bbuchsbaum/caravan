# Compute a deterministic fingerprint for a flow

Fingerprints include stage definitions and the selected parameter grid.
They cannot capture all external dependencies, such as files,
environment variables, databases, or every value accessed dynamically. A
matching hash is not proof that two executions have the same inputs or
results.

## Usage

``` r
flow_fingerprint(fl, limit = NULL, engine = "sequential", validate = "light")
```

## Arguments

- fl:

  A [`flow()`](https://bbuchsbaum.github.io/parade/reference/flow.md)
  object.

- limit:

  Optional row limit for the grid before hashing.

- engine:

  Engine tag included in the fingerprint (default `"sequential"`).

- validate:

  Validation mode tag included in the fingerprint.

## Value

A SHA1 fingerprint string.
