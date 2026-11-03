# Find the most recently created script job registries

Find the most recently created script job registries

## Usage

``` r
script_find_latest(n = 5, pattern = NULL)
```

## Arguments

- n:

  Maximum number of registries to return

- pattern:

  Optional pattern to filter registry names

## Value

A tibble with registry paths and modification times

## Examples

``` r
local({
  old_paths <- options(parade.paths = NULL)
  on.exit(options(old_paths), add = TRUE)
  example_dir <- tempfile("caravan-script-jobs-")
  dir.create(example_dir)
  on.exit(unlink(example_dir, recursive = TRUE), add = TRUE)
  paths_init(quiet = TRUE)
  paths_set(registry = file.path(example_dir, "registry"))

  latest_jobs <- script_find_latest(n = 3)
})
```
