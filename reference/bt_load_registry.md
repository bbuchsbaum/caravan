# Load a Caravan batchtools registry with its saved backend

`loadRegistry()` sets cluster functions and synchronizes before
returning. Supply a one-use configuration that restores Caravan's saved
functions before that synchronization, and never rely on an ambient
batchtools.conf.R.

## Usage

``` r
bt_load_registry(reg_dir, writeable = FALSE)
```

## Arguments

- reg_dir:

  Registry directory.

- writeable:

  Whether the caller needs write access.

## Value

A batchtools registry object.
