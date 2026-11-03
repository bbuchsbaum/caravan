# Find log files for a pipeline run

Discovers log files from batchtools registries, SLURM stdout/stderr, and
sacct paths. Returns a tibble with log metadata.

## Usage

``` r
find_logs(x, failed_only = TRUE)
```

## Arguments

- x:

  A `parade_deferred` object

- failed_only:

  If TRUE (default), only return logs for failed chunks

## Value

A tibble with columns: `chunk_id`, `batch_id`, `state`, `log_path`,
`log_size`, `log_lines`

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
  logs <- find_logs(d)
})
#> [parade] submit prune: scanning 2 groups for cached outputs
#> [parade] submit prune complete in 0.0s (0 pruned, 2 pending)
# }
```
