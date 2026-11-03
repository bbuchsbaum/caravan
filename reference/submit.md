# Submit a flow for deferred execution

Submits a caravan flow for asynchronous execution, either locally using
future or on SLURM using batchtools. Returns a handle for monitoring and
collecting results.

## Usage

``` r
submit(
  fl,
  mode = c("index", "results"),
  run_id = NULL,
  registry_dir = NULL,
  index_dir = NULL,
  seed_furrr = TRUE,
  scheduling = 1,
  clean = FALSE,
  label = NULL
)
```

## Arguments

- fl:

  A `parade_flow` object with distribution settings

- mode:

  Execution mode: "index" (default) or "results"

- run_id:

  Optional run identifier (auto-generated if NULL)

- registry_dir:

  Directory for execution registry

- index_dir:

  Directory for result indices

- seed_furrr:

  Whether to enable deterministic random number generation

- scheduling:

  Furrr scheduling parameter

- clean:

  If `TRUE`, remove an existing registry directory before creating a new
  one. Useful when retrying after a failed submission.

- label:

  Optional human-readable submit label. Used to derive the default
  registry directory name and backend job/task names.

## Value

A `parade_deferred` object for monitoring execution

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
deferred_await(deferred, timeout = 60)
})
#> [parade] submit prune: scanning 2 groups for cached outputs
#> [parade] submit prune complete in 0.0s (0 pruned, 2 pending)
# }
```
