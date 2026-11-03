# Set specific caravan paths

Set specific caravan paths

## Usage

``` r
paths_set(...)
```

## Arguments

- ...:

  Named path specifications to update

## Value

Updated paths list (invisibly)

## Examples

``` r
local({
  old <- options(parade.paths = NULL)
  on.exit(options(old), add = TRUE)
  paths_set(data = "/custom/data", artifacts = "/tmp/artifacts")
})
```
