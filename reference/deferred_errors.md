# Comprehensive error detection for a deferred pipeline

Combines three error sources into a single tibble:

1.  **Index errors**: Rows where `.diag` has `ok=FALSE`

2.  **SLURM crashes**: Jobs in FAILED/CANCELLED/TIMEOUT state

3.  **Missing indices**: SLURM job COMPLETED but no index file written

## Usage

``` r
deferred_errors(d)
```

## Arguments

- d:

  A `parade_deferred` object

## Value

A tibble with columns: `chunk_id`, `row`, `stage`, `error_msg`, `source`
(one of "index", "slurm", "missing"), and `context`

## Examples

``` r
# \donttest{
local({
  old_options <- options(parade.paths = NULL, parade.log_path = NULL)
  on.exit(options(old_options), add = TRUE)
  example_dir <- tempfile("parade-example-")
  dir.create(example_dir)
  on.exit(unlink(example_dir, recursive = TRUE), add = TRUE)
  paths_init(profile = "local", quiet = TRUE)
  paths_set(registry = file.path(example_dir, "registry"),
            artifacts = file.path(example_dir, "artifacts"))
grid <- data.frame(x = 1:4, group = rep(c("A", "B"), 2))
fl <- flow(grid) |>
  stage("calc", function(x) list(result = x^2), schema = returns(result = dbl())) |>
  distribute(dist_local(by = "group", within = "sequential"))
d <- submit(fl)
deferred_await(d, timeout = 60)
errs <- deferred_errors(d)
})
#> [parade] submit prune: scanning 2 groups for cached outputs
#> [parade] submit prune complete in 0.0s (0 pruned, 2 pending)
# }
```
