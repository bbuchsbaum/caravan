# Quick setup checks for caravan

Runs a set of lightweight checks aimed at getting started quickly. This
includes path validation and basic HPC-specific recommendations.

## Usage

``` r
parade_doctor(create = FALSE, quiet = FALSE)
```

## Arguments

- create:

  Whether to create missing directories for path roots.

- quiet:

  Whether to suppress printing and only return results.

## Value

The result from
[paths_validate](https://bbuchsbaum.github.io/parade/reference/paths_validate.md)
(invisibly).

## Examples

``` r
parade_doctor()
#> parade doctor
#> ------------
#> [OK] project    /home/runner/work/parade/parade/docs/reference
#> [OK] scratch    /tmp/RtmpUmpvNB
#> [WARN] data       /home/runner/work/parade/parade/docs/reference/data
#>        Directory does not exist.
#> [WARN] artifacts  /tmp/RtmpUmpvNB/parade-artifacts
#>        Directory does not exist.
#> [WARN] registry   /tmp/RtmpUmpvNB/parade-registry
#>        Directory does not exist.
#> [WARN] config     /home/runner/work/parade/parade/docs/reference/.parade
#>        Directory does not exist.
#> [WARN] cache      /home/runner/.cache/R/parade
#>        Directory does not exist.
#> 
#> Warnings
#> --------
#> - Missing directory for: data, artifacts, registry, config, cache 
```
