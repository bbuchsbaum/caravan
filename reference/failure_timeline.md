# Build a chronological timeline of failures

Combines `.diag` timestamps, SLURM sacct times, and event store data to
produce a chronological view of what happened during a pipeline run.

## Usage

``` r
failure_timeline(x, around_failure = 60, ...)
```

## Arguments

- x:

  A `parade_deferred` object or collected results data.frame

- around_failure:

  Seconds of context to show around each failure event

- ...:

  Additional arguments (unused)

## Value

A tibble with columns: `offset`, `offset_str`, `event`, `chunk_id`,
`stage`, `context`, `class`

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
tl <- failure_timeline(d)
})
#> [parade] submit prune: scanning 2 groups for cached outputs
#> [parade] submit prune complete in 0.0s (0 pruned, 2 pending)
# }
```
