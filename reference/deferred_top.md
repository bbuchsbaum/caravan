# Live TUI monitor for deferred jobs

Displays a live-updating terminal dashboard for a `parade_deferred`
object. Adapts to the backend: SLURM gets a rich per-chunk table with
metrics and log tailing; local/crew/mirai get a progress bar with
resolved/unresolved counts.

## Usage

``` r
deferred_top(
  d,
  refresh = 3,
  nlog = 20,
  clear = TRUE,
  once = FALSE,
  max_rows = 20L
)
```

## Arguments

- d:

  A `parade_deferred` object (from
  [`submit()`](https://bbuchsbaum.github.io/parade/reference/submit.md))

- refresh:

  Seconds between display updates (default 3)

- nlog:

  Number of log lines to show (SLURM only, default 20)

- clear:

  Clear screen between updates (default TRUE)

- once:

  Single-shot mode: display once and return (default FALSE)

- max_rows:

  Maximum chunk rows to display (default 20). Remaining chunks are
  summarised in a single line.

## Value

The input deferred object (invisibly)

## Details

Progress is tracked via index file counting (`index-NNNN.rds` in
`d$index_dir`), which works across all backends.

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
  grid <- data.frame(x = 1:6, g = rep(1:3, 2))
  fl <- flow(grid) |>
    stage("s", function(x) list(y = x^2), schema = returns(y = dbl())) |>
    distribute(dist_local(by = "g", within = "sequential"))
  d <- submit(fl)
  deferred_top(d, refresh = 1, once = TRUE)
  deferred_await(d, timeout = 60)
})
#> [parade] submit prune: scanning 3 groups for cached outputs
#> [parade] submit prune complete in 0.0s (0 pruned, 3 pending)
#> caravan::deferred_top  -
#> 
#> Run: 1f93c033  Backend: local  Submitted: 2026-11-03 15:32:32.739597
#> Elapsed: 0:00:01  By: g  Mode: index
#> Stages: s
#> 
#> Progress [########################]  100%  (3/3 chunks)
#>   total=3  resolved=3  unresolved=0
#> 
#> (All chunks completed)
#> 
# }
```
