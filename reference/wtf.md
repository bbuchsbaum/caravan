# Diagnose pipeline failures

The primary entry point for understanding what went wrong in a caravan
pipeline run. Provides classified errors, actionable suggestions, and
log locations.

## Usage

``` r
wtf(x, verbose = 2L, max_errors = 20L, log_lines = 15L, ...)
```

## Arguments

- x:

  A `parade_deferred` object, collected results data.frame,
  `parade_script_job`, or `parade_jobset`

- verbose:

  Detail level: 0 (summary only), 1 (errors), 2 (full report with
  suggestions and logs)

- max_errors:

  Maximum number of individual errors to display

- log_lines:

  Number of log tail lines to show per failed chunk

- ...:

  Additional arguments passed to methods

## Value

A `parade_failure_report` object (invisibly), printed as side effect

## Examples

``` r
# \donttest{
local({
  old <- options(parade.paths = NULL, parade.log_path = NULL)
  on.exit(options(old), add = TRUE)
  example_dir <- tempfile("caravan-example-")
  dir.create(example_dir)
  on.exit(unlink(example_dir, recursive = TRUE), add = TRUE)
  paths_init(profile = "local", quiet = TRUE)
  paths_set(registry = file.path(example_dir, "registry"),
            artifacts = file.path(example_dir, "artifacts"))
  grid <- data.frame(x = 1:4, group = rep(c("A", "B"), 2))
  fl <- flow(grid) |>
    stage("calc", function(x) list(result = x^2),
          schema = returns(result = dbl())) |>
    distribute(dist_local(by = "group", within = "sequential"))
  d <- submit(fl)
  deferred_await(d, timeout = 60)
  wtf(d)
})
#> [parade] submit prune: scanning 2 groups for cached outputs
#> [parade] submit prune complete in 0.0s (0 pruned, 2 pending)
#> 
#> ================================================================================ 
#> parade failure report
#> Run: 7cd9e467  Backend: local  Submitted: 2026-11-03 15:33:17.247665
#> Stages: calc
#> Elapsed: 0:00:00  Chunks: 2 total, 2 ok, 0 failed
#> 
#> No failures detected.
#> ================================================================================ 
#> 
# }
```
