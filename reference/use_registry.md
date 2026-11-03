# Get or set active registry

Manage which registry is currently active for job storage.

## Usage

``` r
use_registry(path = NULL, create = TRUE)
```

## Arguments

- path:

  Path to registry directory

- create:

  If TRUE, create directory if it doesn't exist

## Value

Current registry path

## Examples

``` r
# \donttest{
local({
  old <- options(parade.paths = NULL)
  on.exit(options(old), add = TRUE)
  example_dir <- tempfile("caravan-registry-")
  on.exit(unlink(example_dir, recursive = TRUE), add = TRUE)
  use_registry(example_dir)
  use_registry()
})
#> Created registry: /tmp/RtmpUmpvNB/caravan-registry-19f65d1f53a9
#> Using registry: /tmp/RtmpUmpvNB/caravan-registry-19f65d1f53a9
#> Current registry: /tmp/RtmpUmpvNB/caravan-registry-19f65d1f53a9
# }
```
