# Internal helpers for batchtools compatibility

#' Create a batchtools registry with best-effort compatibility
#'
#' Some older versions of batchtools do not support the
#' `cluster.functions` argument in `makeRegistry()`. This helper
#' tries the modern call first, and falls back to creating the
#' registry without the argument and assigning the cluster functions
#' on the returned registry object.
#'
#' @return A batchtools registry object.
#' @keywords internal
bt_make_registry <- function(reg_dir, cf) {
  stopifnot(requireNamespace("batchtools", quietly = TRUE))
  make_registry <- function(...) {
    withCallingHandlers(
      batchtools::makeRegistry(...),
      message = function(cnd) {
        if (grepl(
          "No readable configuration file found",
          conditionMessage(cnd),
          fixed = TRUE
        )) {
          invokeRestart("muffleMessage")
        }
      }
    )
  }
  # Try the modern API first
  reg <- tryCatch({
    make_registry(
      file.dir = reg_dir,
      make.default = FALSE,
      conf.file = NA,
      cluster.functions = cf
    )
  }, error = function(e) {
    msg <- conditionMessage(e)
    if (grepl("unused argument", msg, fixed = TRUE) && grepl("cluster.functions", msg, fixed = TRUE)) {
      # Fallback for older batchtools: create then assign CF
      reg <- make_registry(
        file.dir = reg_dir,
        make.default = FALSE,
        conf.file = NA
      )
      # Assign cluster functions directly on the registry object
      # (works across older batchtools releases)
      reg$cluster.functions <- cf
      reg
    } else {
      stop(e)
    }
  })
  .bt_write_cluster_functions(reg_dir, cf)
  reg
}

.bt_cluster_functions_path <- function(reg_dir) {
  file.path(reg_dir, "parade-cluster-functions.rds")
}

# batchtools deliberately omits `cluster.functions` from registry.rds. Keep
# this small sidecar inside the registry instead of consulting a later
# session's ambient batchtools configuration.
.bt_write_cluster_functions <- function(reg_dir, cf) {
  path <- .bt_cluster_functions_path(reg_dir)
  tmp <- tempfile("parade-cluster-functions-", tmpdir = dirname(path))
  on.exit(unlink(tmp, force = TRUE), add = TRUE)
  saveRDS(list(version = 1L, cluster_functions = cf), tmp)
  if (!file.rename(tmp, path)) {
    stop("Could not persist Parade cluster functions for registry: ", reg_dir,
         call. = FALSE)
  }
  invisible(path)
}

.bt_read_cluster_functions <- function(reg_dir) {
  path <- .bt_cluster_functions_path(reg_dir)
  if (!file.exists(path)) {
    stop("Registry has no Parade cluster-functions metadata: ", reg_dir,
         ". It cannot be safely reloaded without its original backend configuration.",
         call. = FALSE)
  }
  metadata <- tryCatch(readRDS(path), error = function(e) {
    stop("Could not read Parade cluster-functions metadata for registry: ", reg_dir,
         ". ", conditionMessage(e), call. = FALSE)
  })
  cf <- metadata$cluster_functions %||% NULL
  if (!inherits(cf, "ClusterFunctions")) {
    stop("Registry has invalid Parade cluster-functions metadata: ", reg_dir,
         call. = FALSE)
  }
  cf
}

#' Load a Caravan batchtools registry with its saved backend
#'
#' `loadRegistry()` sets cluster functions and synchronizes before returning.
#' Supply a one-use configuration that restores Caravan's saved functions before
#' that synchronization, and never rely on an ambient batchtools.conf.R.
#'
#' @param reg_dir Registry directory.
#' @param writeable Whether the caller needs write access.
#' @return A batchtools registry object.
#' @keywords internal
bt_load_registry <- function(reg_dir, writeable = FALSE) {
  stopifnot(requireNamespace("batchtools", quietly = TRUE))
  reg_dir <- normalizePath(reg_dir, mustWork = TRUE)
  cf <- .bt_read_cluster_functions(reg_dir)
  config <- tempfile("parade-batchtools-config-", fileext = ".R")
  on.exit(unlink(config, force = TRUE), add = TRUE)
  cf_path <- paste(utils::capture.output(dput(.bt_cluster_functions_path(reg_dir))), collapse = "")
  writeLines(c(
    paste0("cluster.functions <- readRDS(", cf_path, ")$cluster_functions"),
    "default.resources <- list()"
  ), config, useBytes = TRUE)

  reg <- batchtools::loadRegistry(
    file.dir = reg_dir,
    conf.file = config,
    make.default = FALSE,
    writeable = isTRUE(writeable)
  )
  if (!inherits(reg$cluster.functions, "ClusterFunctions") ||
      !identical(reg$cluster.functions$name, cf$name)) {
    stop("Could not establish the saved Parade backend for registry: ", reg_dir,
         call. = FALSE)
  }
  reg
}
