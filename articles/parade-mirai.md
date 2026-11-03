# Mirai backend: fast, scalable parallel execution

## Why mirai?

The mirai backend brings several powerful advantages to caravan
workflows:

- **Connections**: Mirai can avoid the usual R connection limit
- **Low-latency execution**: Persistent daemons with dispatcher for
  minimal overhead
- **Secure remote execution**: Built-in TLS and SSH tunneling support
- **HPC compliance**: Launch daemons through SLURM while maintaining
  scheduler policies
- **Local development**: Run a flow using local daemons

## Quick Start

### Local development

The simplest way to use mirai is as a replacement for the standard
multisession backend:

``` r

library(caravan)

# Submit a small flow to two local daemons
grid <- data.frame(x = 1:4)
fl <- flow(grid) |>
  stage("process", function(x) list(y = x^2), schema = returns(y = dbl())) |>
  distribute(use_mirai_local(n = 2))
handle <- submit(fl)
deferred_await(handle)
results <- deferred_collect(handle)
mirai_stop()
results
```

Use
[`submit()`](https://bbuchsbaum.github.io/parade/reference/submit.md) to
dispatch the flow to the configured mirai backend. `collect(fl)` follows
the blocking flow path and does not submit to mirai. Both `mirai` and
`future.mirai` must be installed.

### Comparison with other backends

| Scenario | Traditional | Mirai | Benefits |
|----|----|----|----|
| Many small tasks | [`dist_local()`](https://bbuchsbaum.github.io/parade/reference/dist_local.md) | [`use_mirai_local()`](https://bbuchsbaum.github.io/parade/reference/use_mirai_local.md) | Persistent daemons may reduce overhead |
| Many workers | Local futures | `dist_mirai(n = 200)` | Avoids the usual R connection limit; resources still apply |
| Remote execution | Complex setup | [`use_mirai_ssh()`](https://bbuchsbaum.github.io/parade/reference/use_mirai_ssh.md) | Built-in SSH tunneling |
| HPC clusters | [`dist_slurm()`](https://bbuchsbaum.github.io/parade/reference/dist_slurm.md) | [`use_mirai_slurm()`](https://bbuchsbaum.github.io/parade/reference/use_mirai_slurm.md) | Persistent workers; check site configuration |

## Distribution Patterns

### 1. Local Daemons

For development and single-machine workflows:

``` r

# Basic local setup
dist <- dist_mirai(n = 8)

# With explicit configuration
dist <- dist_mirai(
  n = parallel::detectCores(),
  dispatcher = TRUE,  # Enable load balancing
  within = "mirai",   # Use mirai for nested parallelization
  workers_within = 4  # Nested workers per daemon
)

# Apply to flow
handle <- fl |> distribute(dist) |> submit()
deferred_await(handle)
results <- deferred_collect(handle)
mirai_stop()
```

### 2. SLURM-Managed Daemon Pools

Launch mirai daemons through SLURM for HPC-compliant distributed
execution:

``` r

# Configure SLURM-launched daemons
dist <- use_mirai_slurm(
  n = 16,                    # Number of daemon jobs
  partition = "compute",     # SLURM partition
  time = "2:00:00",         # Wall time
  mem = "32G",              # Memory per daemon
  cpus = 8,                 # CPUs per daemon
  tls = TRUE,               # Use TLS encryption
  port = 5555               # TLS port
)

# Submit flow with SLURM daemons
handle <- fl |>
  distribute(dist) |>
  submit()

# Monitor status
deferred_status(handle)
deferred_await(handle)
results <- deferred_collect(handle)
mirai_stop()
```

Confirm the configuration with your cluster administrator before
submitting jobs. In the current implementation,
`use_mirai_slurm(n = ...)` does not pass `n` to the remote daemon
launch, so do not rely on it to set the daemon count.

### 3. SSH Tunneling for Firewalled Clusters

Connect to remote nodes through SSH, even when direct connections are
blocked:

``` r

# SSH with tunneling (for firewalled nodes)
dist <- use_mirai_ssh(
  remotes = c("ssh://node1", "ssh://node2", "ssh://node3"),
  tunnel = TRUE,      # Use SSH tunneling
  port = 40491       # Local port for tunnel
)

# Direct SSH (when ports are open)
dist <- use_mirai_ssh(
  remotes = c("ssh://compute1", "ssh://compute2"),
  tunnel = FALSE
)

handle <- fl |> distribute(dist) |> submit()
deferred_await(handle)
results <- deferred_collect(handle)
mirai_stop()
```

SSH tunneling allows secure connections even in restricted network
environments.

## Advanced Configuration

### Manual Daemon Setup

For full control over the mirai configuration:

``` r

library(mirai)
library(future)

# Set up custom TLS-secured daemons
url <- host_url(tls = TRUE, port = 5555)

# Configure SLURM submission
opts <- paste(
  "#SBATCH --partition=highmem",
  "#SBATCH --time=04:00:00",
  "#SBATCH --mem=64G",
  "#SBATCH --job-name=my-analysis",
  sep = "\n"
)

cfg <- cluster_config(command = "sbatch", options = opts)

# Launch daemons
daemons(n = 32, url = url, remote = cfg, dispatcher = TRUE)

# Use with parade via future
plan(future.mirai::mirai_cluster)
fl |> collect()
```

### Dynamic Scaling

Adjust daemon count based on workload:

``` r

# Start with a few daemons
mirai_init(n = 4)

# Scale up for intensive processing
mirai_scale(16)
results <- collect(heavy_flow)  # Requires a future.mirai plan configured separately

# Scale down when done
mirai_scale(4)

# Check status
mirai_status()
mirai_dispatcher_status()
```

### Chunking Strategies

Optimize task distribution with mirai’s dispatcher:

``` r

# Fine-grained parallelism (many small tasks)
dist_mirai(
  n = 16,
  dispatcher = TRUE,     # Essential for load balancing
  chunks_per_job = 1     # One group per task
)

# Coarse-grained parallelism (fewer large tasks)
dist_mirai(
  n = 8,
  dispatcher = FALSE,    # Direct task assignment
  chunks_per_job = 10    # Bundle groups together
)
```

## Practical Examples

### Example 1: Large-scale simulation on local machine

``` r

library(caravan)

# Parameter grid with 10,000 combinations
grid <- expand.grid(
  alpha = seq(0.1, 1, by = 0.1),
  beta = seq(0.5, 5, by = 0.5),
  n_sim = 1:100
)

# Use mirai to bypass connection limits
fl <- flow(grid) |>
  stage("simulate", function(alpha, beta, n_sim) {
    set.seed(n_sim)
    data <- rgamma(1000, shape = alpha, rate = beta)
    list(
      mean = mean(data),
      var = var(data),
      ks_p = ks.test(data, "pgamma", alpha, beta)$p.value
    )
  }, schema = returns(mean = dbl(), var = dbl(), ks_p = dbl())) |>
  distribute(dist_mirai(n = 200))  # 200 workers!

handle <- submit(fl)
deferred_await(handle)
results <- deferred_collect(handle)
mirai_stop()
```

### Example 2: Remote execution on HPC cluster

``` r

# Development: test locally
fl_dev <- fl |> 
  distribute(use_mirai_local(n = 4))

test_handle <- submit(fl_dev)
deferred_await(test_handle)
test_results <- deferred_collect(test_handle)
mirai_stop()

# Production: scale to cluster
fl_prod <- fl |>
  distribute(use_mirai_slurm(
    n = 64,
    partition = "compute",
    time = "12:00:00",
    mem = "256G",
    account = "project-123"
  ))

handle <- submit(fl_prod)

# Monitor progress
while (deferred_status(handle)$unresolved > 0) {
  status <- deferred_status(handle)
  print(status)
  Sys.sleep(30)
}

final_results <- deferred_collect(handle)
mirai_stop()
```

### Example 3: Cross-platform workflow

``` r

# Detect environment and choose appropriate backend
get_distribution <- function() {
  if (Sys.getenv("SLURM_JOB_ID") != "") {
    # Running on SLURM
    use_mirai_slurm(n = 32, partition = "compute")
  } else if (file.exists("~/.ssh/compute_nodes")) {
    # Has SSH access to compute nodes
    nodes <- readLines("~/.ssh/compute_nodes")
    use_mirai_ssh(remotes = nodes, tunnel = TRUE)
  } else {
    # Local development
    use_mirai_local()
  }
}

# Portable workflow
handle <- fl |>
  distribute(get_distribution()) |>
  submit()
deferred_await(handle)
results <- deferred_collect(handle)
mirai_stop()
```

## Performance Considerations

### When to use mirai vs traditional backends

| Use Case | Best Choice | Reasoning |
|----|----|----|
| Few large tasks | [`dist_local()`](https://bbuchsbaum.github.io/parade/reference/dist_local.md) or [`dist_slurm()`](https://bbuchsbaum.github.io/parade/reference/dist_slurm.md) | Traditional backends work well |
| Many small tasks | [`dist_mirai()`](https://bbuchsbaum.github.io/parade/reference/dist_mirai.md) | Lower per-task overhead |
| Many parallel tasks | [`dist_mirai()`](https://bbuchsbaum.github.io/parade/reference/dist_mirai.md) | Avoids the usual R connection limit |
| Need load balancing | `dist_mirai(dispatcher = TRUE)` | Automatic work distribution |
| Firewalled cluster | `use_mirai_ssh(tunnel = TRUE)` | SSH tunneling support |
| Require TLS security | `dist_mirai(tls = TRUE)` | Built-in encryption |

### Optimizing dispatcher performance

The dispatcher provides automatic load balancing but adds slight
overhead:

``` r

# For homogeneous tasks (similar runtime)
dist_mirai(n = 16, dispatcher = FALSE)

# For heterogeneous tasks (varying runtime)
dist_mirai(n = 16, dispatcher = TRUE)

# For embarrassingly parallel workflows
dist_mirai(
  n = 32,
  dispatcher = TRUE,
  chunks_per_job = 1  # Maximum parallelism
)
```

## Troubleshooting

### Common issues and solutions

**Issue**: “Cannot connect to daemons”

``` r

# Check daemon status
mirai_status()

# Restart daemons
mirai_stop()
mirai_init()
```

**Issue**: “Tasks not distributing evenly”

``` r

# Ensure dispatcher is enabled
dist_mirai(n = 16, dispatcher = TRUE)

# Check dispatcher status
mirai_dispatcher_status()
```

**Issue**: “SSH connection fails”

``` r

# Test SSH manually first
system("ssh node1 echo 'connected'")

# Use verbose mode for debugging
Sys.setenv(MIRAI_DEBUG = "TRUE")
```

**Issue**: “SLURM daemons not starting”

``` r

# Check SLURM submission manually
mirai::daemons(
  n = 1,
  url = mirai::host_url(tls = TRUE),
  remote = mirai::cluster_config(
    command = "sbatch",
    options = "#SBATCH --partition=debug\n#SBATCH --time=00:05:00"
  )
)

# Check SLURM queue
system("squeue -u $USER")
```

## Best Practices

1.  **Clean up daemons**: Call
    [`mirai_stop()`](https://bbuchsbaum.github.io/parade/reference/mirai_stop.md)
    after collection. In the current implementation `stop_on_exit`
    controls cleanup on
    [`deferred_cancel()`](https://bbuchsbaum.github.io/parade/reference/deferred_cancel.md),
    not normal collection. Stopping daemons affects the current mirai
    session.

2.  **Choose appropriate daemon count**:

    - Local: number of cores
    - Remote: match workers to allocated resources
    - SLURM: Based on partition limits

3.  **Configure TLS for remote connections**: Confirm encryption and
    site settings before sending sensitive data. Local daemon submission
    does not use the `tls` argument. Configure TLS in the remote
    connection and verify the setup for your site.

4.  **Monitor resource usage**: Track daemon performance

    ``` r

    # During execution
    mirai_dispatcher_status()

    # After completion
    mirai_status()
    ```

5.  **Test locally before scaling**: Verify workflow correctness

    ``` r

    # Development
    # Build the same stages on a small input grid, then submit locally.

    # Production
    fl |> distribute(use_mirai_slurm(n = 64)) |> submit()
    ```

## Summary

The mirai backend extends caravan’s capabilities with:

- **Parallelism**: Mirai avoids the usual R connection limit, subject to
  available resources
- **Flexible deployment**: Local, SSH, or SLURM
- **Enhanced security**: TLS and SSH tunneling
- **Performance**: Persistent daemons can reduce task overhead
- **Interface**: Configure a backend and submit a flow

Whether you’re developing locally or scaling to hundreds of nodes, mirai
provides the performance and flexibility needed for modern parallel
computing workflows.
