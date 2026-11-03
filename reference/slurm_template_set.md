# Set the default SLURM template path

Set the default SLURM template path

## Usage

``` r
slurm_template_set(path, persist = TRUE)
```

## Arguments

- path:

  Path to SLURM template file

- persist:

  Whether to save to configuration file

## Value

Resolved template path (invisibly)

## Examples

``` r
local({
  old <- options(parade.slurm.template = NULL)
  on.exit(options(old), add = TRUE)
  temp_file <- tempfile(fileext = ".tmpl")
  on.exit(unlink(temp_file), add = TRUE)
  writeLines("#!/bin/bash", temp_file)
  slurm_template_set(temp_file, persist = FALSE)
})
```
