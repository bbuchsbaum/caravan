# Wait for deferred execution to complete

Wait for deferred execution to complete

## Usage

``` r
deferred_await(d, timeout = Inf, poll = 10)
```

## Arguments

- d:

  A `parade_deferred` object

- timeout:

  Maximum time to wait in seconds

- poll:

  Polling interval in seconds

## Value

The input deferred object (invisibly)

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
deferred <- submit(fl)
deferred_await(deferred, timeout = 600)
})
#> [parade] submit prune: scanning 2 groups for cached outputs
#> [parade] submit prune complete in 0.0s (0 pruned, 2 pending)
# }
```
