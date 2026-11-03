# Smart Path Management: Write Once, Run Anywhere

> Note: Code evaluation is disabled in this vignette to keep builds fast
> and environment-agnostic. Copy code into an interactive R session to
> run locally or on your cluster.

## The Problem: Hardcoded Paths Break Your Code

Imagine you’re developing a neuroimaging analysis on your laptop. Your
code might look like this:

``` r

# Works on your laptop
model <- readRDS("/Users/alice/projects/brain_study/models/brain_model.rds")
results <- analyze_brain(model)
saveRDS(results, "/Users/alice/projects/brain_study/outputs/results.rds")
```

But when you or a collaborator runs this code on an HPC cluster, it
breaks immediately:

- `/Users/alice/` doesn’t exist on Linux clusters
- Different clusters have completely different filesystem layouts
- Writing large files to home directories often violates cluster
  policies
- Your collaborator Bob can’t run your code without rewriting all the
  paths

## The Solution: Portable Path Aliases

**caravan** provides path aliases that you can configure for each
environment:

``` r

library(caravan)

# Same code works everywhere
model <- readRDS(resolve_path("artifacts://models/brain_model.rds"))
results <- analyze_brain(model)
saveRDS(results, resolve_path("artifacts://outputs/results.rds"))
```

The `artifacts://` prefix is a **portable alias** that caravan
automatically translates:

- **On your laptop**: → `/var/folders/.../parade-artifacts/`
- **On SLURM cluster**: → `$PARADE_SCRATCH/parade-artifacts/`
  (preferred) or `$SCRATCH/parade-artifacts/` (common). If neither is
  set, it falls back to `$SLURM_TMPDIR` (node-local scratch).
- **On your collaborator’s machine**: → whatever their appropriate
  storage location is

Configure the alias roots on each system, and ensure that the required
files are available there.

## HPC quickstart (recommended)

On clusters, the main “gotcha” is **node-local scratch**: `SLURM_TMPDIR`
is often local to the compute node running a job. If you put
`registry://` or `artifacts://` there, other jobs (or your login node)
may not be able to see the files.

The recommended setup is:

1.  Point Caravan at **shared scratch** (site-specific).
2.  Initialize paths in **HPC mode** (especially on login nodes).
3.  Run the built-in doctor once to confirm everything is writable.

``` sh
# In your shell (recommended for most clusters)
export PARADE_SCRATCH="/scratch/$USER"   # or your site's shared scratch
```

``` r

library(caravan)

# Auto-detects HPC on compute nodes (scheduler vars), and on many login nodes
# when common scratch variables (SCRATCH/WORK/etc.) are set:
paths_init(profile = "auto", create = TRUE)
parade_doctor(create = TRUE)
```

Or use the one-command helper (creates paths, scaffolds a SLURM
template, and can persist to `parade.json`):

``` r

parade_init_hpc(persist = TRUE)
```

To make the configuration easy to reuse in SLURM scripts, you can also
generate shell exports:

``` r

cat(paste(paths_export(), collapse = "\n"))
```

If you prefer not to create directories automatically, use:

``` r

paths_init(profile = "hpc")
paths_validate(create = FALSE)
```

## Quick Start: Your First Portable Analysis

Let’s make a simple analysis portable in three steps:

### Step 1: Initialize caravan’s path system

``` r

library(caravan)

# Auto-detect your environment and set up paths
paths_init()

# Tip (HPC): on a login node or if your scheduler env isn't set, use:
# paths_init(profile = "hpc"); parade_doctor(create = TRUE)

# See where your aliases point
paths_get()
#> project:   /home/alice/myproject
#> data:      /home/alice/myproject/data
#> artifacts: /tmp/RtmpXYZ/parade-artifacts
#> registry:  /tmp/RtmpXYZ/parade-registry
```

### Step 2: Use aliases instead of hardcoded paths

``` r

# Before (breaks on different systems):
data <- read.csv("/home/alice/myproject/data/experiment.csv")
saveRDS(model, "/home/alice/myproject/outputs/model.rds")

# After (works everywhere):
data <- read.csv(resolve_path("data://experiment.csv"))
saveRDS(model, resolve_path("artifacts://model.rds"))
```

### Step 3: Run the same code anywhere

``` r

# On your laptop
paths_init()
saveRDS(big_model, resolve_path("artifacts://models/final.rds"))
# Saves to: /var/folders/temp/parade-artifacts/models/final.rds

# On HPC cluster (same code!)
paths_init(profile = "hpc")
saveRDS(big_model, resolve_path("artifacts://models/final.rds"))
# Saves to: $PARADE_SCRATCH/parade-artifacts/models/final.rds (or $SCRATCH/parade-artifacts/...)
```

That’s it! Your code now works on any system without modification.

## Understanding the Seven Path Aliases

caravan provides seven aliases, each designed for a specific type of
data in your workflow:

### Core Data Aliases

**`data://`** - Input datasets (read-only)

``` r

# Your raw data, reference files, shared datasets
brain_atlas <- readRDS(resolve_path("data://references/MNI_atlas.rds"))
subjects <- read.csv(resolve_path("data://participants.csv"))
```

**`artifacts://`** - Analysis outputs (large files)

``` r

# Models, results, processed data - goes to fast scratch storage
saveRDS(fitted_model, resolve_path("artifacts://models/model_v2.rds"))
write.csv(results, resolve_path("artifacts://results/final_results.csv"))
```

**`project://`** - Your code and scripts

``` r

# Source files, small configuration files
source(resolve_path("project://R/analysis_functions.R"))
params <- yaml::read_yaml(resolve_path("project://config/params.yaml"))
```

### System Aliases

**`scratch://`** - Temporary files (deleted after jobs)

``` r

# Intermediate files, working data
temp_file <- "scratch://temp_processing.rds"
```

**`registry://`** - Job management files

``` r

# SLURM templates, job scripts (managed by parade)
template <- "registry://templates/my_slurm.tmpl"
```

**`config://`** - caravan configuration

``` r

# Settings, profiles (usually automatic)
"config://profiles/production.json"
```

**`cache://`** - Downloaded/cached data

``` r

# Reusable downloads, package data
"cache://downloaded/large_dataset.tar.gz"
```

## Common Scenarios

### Scenario 1: Laptop Development → HPC Production

You’re developing on your laptop with small test data, then running full
analysis on a cluster:

``` r

# During development (laptop)
paths_init()
paths_set(
  data = "~/projects/test_data",      # Small test dataset
  artifacts = "~/projects/outputs"     # Local outputs
)

# Your analysis code (unchanged!)
run_analysis <- function() {
  data <- readRDS(resolve_path("data://brain_scans.rds"))
  model <- fit_model(data)
  saveRDS(model, resolve_path("artifacts://fitted_model.rds"))
}

# In production (HPC cluster) 
paths_init()
paths_set(
  data = "/shared/datasets/full_data",     # Full dataset
  artifacts = file.path("/scratch", Sys.getenv("USER"), "outputs")
)

# Same analysis code still works!
run_analysis()
```

### Scenario 2: Collaboration with Different Systems

Alice and Bob are collaborating but have different setups:

``` r

# Alice's setup (Mac laptop)
paths_init()
#> artifacts: /var/folders/abc/temp/parade-artifacts

# Bob's setup (Linux workstation) 
paths_init()
#> artifacts: /tmp/bob/parade-artifacts

# Shared analysis code (works for both!)
analyze_subjects <- function(subjects) {
  for (subj in subjects) {
    data <- readRDS(resolve_path(sprintf("data://subjects/%s.rds", subj)))
    results <- process_subject(data)
    saveRDS(results, resolve_path(sprintf("artifacts://results/%s.rds", subj)))
  }
}
```

### Scenario 3: Multi-stage Pipeline with Different Storage Needs

Different stages of your pipeline need different storage strategies:

``` r

library(caravan)

# Configure storage for each data type
paths_init()
paths_set(
  data = "/shared/readonly/inputs",       # Shared input data
  scratch = Sys.getenv("SLURM_TMPDIR"),  # Fast local SSD
  artifacts = file.path("/scratch", Sys.getenv("USER"), "outputs")
)

# Assume process_subject() accepts the loaded list and a temporary file path,
# and returns a list. Each stage returns fields declared in its schema.
flow(subjects) |>
  stage("load", function(subject) {
    list(data = readRDS(resolve_path(sprintf("data://raw/%s.rds", subject))))
  }, schema = returns(data = lst())) |>
  stage("process", function(subject, load.data) {
    temp_file <- resolve_path(sprintf("scratch://processing_%s.rds", subject))
    list(processed = process_subject(load.data, temp_file))
  }, needs = "load", schema = returns(processed = lst())) |>
  stage("save", function(subject, process.processed) {
    saveRDS(process.processed, resolve_path(sprintf("artifacts://final/%s.rds", subject)))
    list(saved = TRUE)
  }, needs = "process", schema = returns(saved = lgl()))
```

## Configuring for Your HPC System

### Automatic Detection

caravan automatically detects common HPC environments:

``` r

# Auto-detects SLURM
paths_init()
# Automatically uses $SLURM_TMPDIR for scratch

# Auto-detects PBS
paths_init()  
# Automatically uses $PBS_O_WORKDIR

# Auto-detects SGE
paths_init()
# Automatically uses $TMPDIR
```

### Manual Configuration

For custom HPC setups, explicitly set your paths:

``` r

# Configure once for your HPC system
paths_set(
  scratch = file.path("/fast/local", Sys.getenv("USER")),
  artifacts = file.path("/lustre", Sys.getenv("USER"), "outputs"),
  registry = file.path("/lustre", Sys.getenv("USER"), "jobs"),
  data = "/projects/shared/datasets"       # Readonly shared data
)

# Save the current paths in the project configuration for future sessions
config <- parade_config_read()
config$paths <- paths_get()
parade_config_write(config)
```

### Environment Variables

Set system-wide defaults via environment variables:

``` bash
# In ~/.bashrc or job scripts
export PARADE_SCRATCH="/fast/scratch/$USER"
export PARADE_ARTIFACTS="/fast/scratch/$USER/outputs"
export PARADE_DATA="/projects/shared/data"
```

## Advanced Patterns

### Pattern 1: Dynamic Environment Switching

``` r

# Detect and configure based on environment
setup_paths <- function() {
  if (interactive()) {
    # Development settings
    paths_set(artifacts = "~/temp/dev_outputs")
    message("Using development paths")
    
  } else if (Sys.getenv("SLURM_JOB_ID") != "") {
    # Production SLURM settings
    paths_set(
      scratch = Sys.getenv("SLURM_TMPDIR"),
      artifacts = sprintf("/scratch/%s/prod_outputs", Sys.getenv("USER"))
    )
    message("Using SLURM production paths")
    
  } else {
    # Default settings
    paths_init()
    message("Using default paths")
  }
}
```

### Pattern 2: Project-Specific Organization

``` r

# Organize outputs by analysis phase
paths_set(
  artifacts = file.path("/scratch", Sys.getenv("USER"), "project_X")
)

# Create structured output directories
save_results <- function(phase, name, object) {
  path <- sprintf("artifacts://%s/%s.rds", phase, name)
  saveRDS(object, resolve_path(path))
}

# Usage
save_results("preprocessing", "cleaned_data", cleaned)
save_results("modeling", "final_model", model)
save_results("validation", "cv_results", cv)

# Results in:
# /scratch/$USER/project_X/preprocessing/cleaned_data.rds
# /scratch/$USER/project_X/modeling/final_model.rds
# /scratch/$USER/project_X/validation/cv_results.rds
```

### Pattern 3: Integration with Sinks

``` r

# Sinks automatically use path aliases
sink_spec(
  fields = c("model", "predictions"),
  dir = "artifacts://models",  # Portable path
  template = "{subject}/{session}_{task}.rds"
)

# Different storage for different output types
model_sink <- sink_spec(
  fields = "model",
  dir = "artifacts://large_models",  # Goes to scratch
  format = "rds"
)

config_sink <- sink_spec(
  fields = "params",
  dir = "project://configs",  # Stays with code
  format = "json"
)
```

## Path Resolution Functions

### `resolve_path()` - Convert aliases to absolute paths

``` r

# Resolve any path with an alias
resolve_path("artifacts://model.rds")
#> "/scratch/alice/parade-artifacts/model.rds"

resolve_path("data://raw/scan.nii")
#> "/shared/datasets/raw/scan.nii"

# Works with regular paths too
resolve_path("/absolute/path.txt")   # Already absolute
resolve_path("relative/path.txt")    # Made absolute
```

### `path_here()` - Build paths from components

``` r

# Construct paths programmatically
model_dir <- path_here("artifacts", "models", "v2")
#> "/scratch/alice/parade-artifacts/models/v2"

# Automatically creates directories
output_dir <- path_here("artifacts", "results", create = TRUE)

# Skip auto-creation if needed
temp_path <- path_here("scratch", "temp", create = FALSE)
```

## Troubleshooting

### Issue: “Cannot find path alias”

``` r

# Check your current configuration
paths_get()

# Re-initialize if needed
paths_init()
```

### Issue: “Permission denied” when writing

``` r

# Check that your aliases point to writable locations
paths_get()

# Update to writable directory
paths_set(artifacts = "/tmp/my_outputs")
```

### Issue: Different paths on different nodes

Keep registries and artifacts on shared storage when jobs need to
exchange files. For task-local temporary files only, you can configure
node-local scratch:

``` r

# Use node-local storage for task-local temporary files
paths_set(
  scratch = ifelse(
    Sys.getenv("SLURM_TMPDIR") != "",
    Sys.getenv("SLURM_TMPDIR"),  # Node-local on SLURM
    "/tmp"                          # Fallback
  )
)
```

## Best Practices

1.  **Initialize paths at the start of every script**

    ``` r

    library(caravan)
    paths_init()
    ```

2.  **Use appropriate aliases for different data types**

    - `data://` for inputs (read-only)
    - `artifacts://` for outputs (large files)
    - `scratch://` for temporary files

3.  **Never hardcode absolute paths**

    ``` r

    # Bad
    saveRDS(model, "/home/alice/outputs/model.rds")

    # Good
    saveRDS(model, resolve_path("artifacts://model.rds"))
    ```

4.  **Document your path configuration**

    ``` r

    # Show configuration in logs
    message("Parade paths configured:")
    print(paths_get())
    ```

## Next Steps

Now that you understand portable paths, learn about:

- [Using Artifacts and
  Sinks](https://bbuchsbaum.github.io/parade/articles/parade-artifacts.md)
  for automatic data management
- [SLURM
  Integration](https://bbuchsbaum.github.io/parade/articles/parade-slurm-distribution.md)
  for cluster computing
- [Core Workflow
  Concepts](https://bbuchsbaum.github.io/parade/articles/parade-core.md)
  for building complete pipelines

## Quick Reference

| Function | Purpose | Example |
|----|----|----|
| [`paths_init()`](https://bbuchsbaum.github.io/parade/reference/paths_init.md) | Auto-configure paths | [`paths_init()`](https://bbuchsbaum.github.io/parade/reference/paths_init.md) |
| [`paths_get()`](https://bbuchsbaum.github.io/parade/reference/paths_get.md) | Show current paths | [`paths_get()`](https://bbuchsbaum.github.io/parade/reference/paths_get.md) |
| [`paths_set()`](https://bbuchsbaum.github.io/parade/reference/paths_set.md) | Set custom paths | `paths_set(artifacts = "/scratch")` |
| [`resolve_path()`](https://bbuchsbaum.github.io/parade/reference/resolve_path.md) | Convert alias to absolute | `resolve_path("data://file.csv")` |
| [`path_here()`](https://bbuchsbaum.github.io/parade/reference/path_here.md) | Build path from parts | `path_here("artifacts", "models")` |

| Alias | Use For | Example |
|----|----|----|
| `data://` | Input data | `read.csv(resolve_path("data://input.csv"))` |
| `artifacts://` | Outputs | `saveRDS(m, resolve_path("artifacts://model.rds"))` |
| `scratch://` | Temp files | `"scratch://temp.rds"` |
| `project://` | Code/config | `source(resolve_path("project://R/utils.R"))` |
