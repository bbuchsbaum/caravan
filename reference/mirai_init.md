# Initialize mirai for caravan

One-step initialization of mirai for use with caravan workflows. Sets up
daemons and configures the future plan.

## Usage

``` r
mirai_init(n = NULL, dispatcher = TRUE)
```

## Arguments

- n:

  Number of local daemons (defaults to number of cores)

- dispatcher:

  Use dispatcher for load balancing

## Value

Invisibly returns the previous future plan

## Examples

``` r
# \donttest{
if (requireNamespace("mirai", quietly = TRUE) && 
    requireNamespace("future.mirai", quietly = TRUE)) {
  local({
    old_plan <- future::plan()
    on.exit(future::plan(old_plan), add = TRUE)
    on.exit(mirai_stop(), add = TRUE)
    mirai_init(n = 2)
  })
}
# }
```
