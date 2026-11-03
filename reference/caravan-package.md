# caravan: Declarative Parallel Dataflow with Future/Furrr

Declarative, lazy, compositional dataflow for R on top of
'future'/'furrr', with typed schemas, artifacts, diagnostics, and
HPC-friendly distribution (local, Slurm via
'future.batchtools'/'batchtools', and mirai for high-performance
parallel execution). Adds an ergonomic SLURM layer: generic script
submission from R, live CPU/memory monitors, multi-job dashboards, and
now site/project defaults with NA-as-omit semantics and profiles. The
mirai backend supports configurable parallelism, SSH tunneling, and TLS
security.

## See also

Useful links:

- <https://bbuchsbaum.github.io/parade/>

## Author

**Maintainer**: Bradley R Buchsbaum <brad.buchsbaum@gmail.com>
\[copyright holder\]
