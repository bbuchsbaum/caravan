# Extract and sort parameters used for completion-manifest identity

Drops only caravan's internal bookkeeping columns. Dots are valid in
user parameter names, so they must remain part of the identity rather
than being mistaken for upstream stage output columns.

## Usage

``` r
.manifest_clean_params(row)
```

## Arguments

- row:

  Named list of row values.

## Value

A sorted named list of grid-only parameters.
