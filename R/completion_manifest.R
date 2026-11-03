# Completion Manifest ------------------------------------------------------
#
# Records {params} -> {output_paths} after each successful script_stage
# execution, decoupling "has this been computed?" from template paths.
# Storage: legacy per-stage JSONL plus atomically published record shards.

.manifest_cache <- new.env(parent = emptyenv())

.manifest_cache_key <- function(path) {
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

.manifest_shard_dir <- function(path) paste0(path, ".d")

.manifest_storage_signature <- function(path) {
  shard_dir <- .manifest_shard_dir(path)
  legacy <- if (file.exists(path)) file.info(path)[c("mtime", "size")] else NULL
  # Shards are immutable after same-directory rename. A newly published shard
  # changes directory metadata, so this remains O(1) rather than statting
  # every record on each lookup. Filesystems that delay directory metadata
  # visibility cannot provide coherent cross-host manifest reads.
  shards <- if (dir.exists(shard_dir)) file.info(shard_dir)[c("mtime", "ctime")] else NULL
  list(legacy = legacy, shards = shards)
}

.manifest_cache_get <- function(path) {
  key <- .manifest_cache_key(path)
  if (!file.exists(path) && !dir.exists(.manifest_shard_dir(path))) {
    if (exists(key, envir = .manifest_cache, inherits = FALSE)) {
      rm(list = key, envir = .manifest_cache, inherits = FALSE)
    }
    return(NULL)
  }

  cached <- .manifest_cache[[key]]
  if (is.null(cached)) return(NULL)

  if (identical(cached$storage_signature, .manifest_storage_signature(path))) {
    return(cached$records)
  }

  rm(list = key, envir = .manifest_cache, inherits = FALSE)
  NULL
}

.manifest_cache_set <- function(path, records) {
  key <- .manifest_cache_key(path)
  index <- split(records, vapply(records, function(rec) {
    rec$param_hash %||% NA_character_
  }, character(1)))
  .manifest_cache[[key]] <- list(
    storage_signature = .manifest_storage_signature(path),
    records = records,
    index = index
  )
  invisible(records)
}

.manifest_cache_index <- function(path) {
  key <- .manifest_cache_key(path)
  if (!file.exists(path) && !dir.exists(.manifest_shard_dir(path))) {
    if (exists(key, envir = .manifest_cache, inherits = FALSE)) {
      rm(list = key, envir = .manifest_cache, inherits = FALSE)
    }
    return(NULL)
  }

  cached <- .manifest_cache[[key]]
  if (is.null(cached)) return(NULL)

  if (identical(cached$storage_signature, .manifest_storage_signature(path))) {
    return(cached$index %||% NULL)
  }

  rm(list = key, envir = .manifest_cache, inherits = FALSE)
  NULL
}

.manifest_cache_invalidate <- function(path = NULL) {
  if (is.null(path)) {
    keys <- ls(envir = .manifest_cache, all.names = TRUE)
    if (length(keys)) {
      rm(list = keys, envir = .manifest_cache)
    }
    return(invisible(NULL))
  }

  key <- .manifest_cache_key(path)
  if (exists(key, envir = .manifest_cache, inherits = FALSE)) {
    rm(list = key, envir = .manifest_cache, inherits = FALSE)
  }
  invisible(NULL)
}

# --- Internal helpers -------------------------------------------------------

#' Resolve path to a stage's completion manifest JSONL
#'
#' @param stage_id Character stage identifier.
#' @param config_dir Config directory (defaults to \code{paths_get()$config}).
#' @return Absolute path to the JSONL file.
#' @keywords internal
.manifest_path <- function(stage_id, config_dir = NULL) {

  config_dir <- config_dir %||% paths_get()$config
  file.path(config_dir, "completions", paste0(stage_id, ".jsonl"))
}

#' Extract and sort parameters used for completion-manifest identity
#'
#' Drops only caravan's internal bookkeeping columns. Dots are valid in user
#' parameter names, so they must remain part of the identity rather than being
#' mistaken for upstream stage output columns.
#'
#' @param row Named list of row values.
#' @return A sorted named list of grid-only parameters.
#' @keywords internal
.manifest_clean_params <- function(row) {
  nms <- names(row)
  internal <- c(".grid_id", ".grid_hash", ".ok", ".diag")
  drop <- nms %in% internal | grepl("^\\.run_", nms)
  params <- row[!drop]
  # Sort by name for deterministic hashing
  params[sort(names(params))]
}

#' Append a single record to a manifest JSONL file
#'
#' Atomically publish one completion record.
#'
#' Each record is written to a unique temporary file and renamed within its
#' stage directory. This avoids shared append races and retains legacy JSONL
#' files as read-only input for backwards compatibility.
#'
#' @param path Path to the JSONL file.
#' @param record A list to serialize as one JSON line.
#' @keywords internal
.manifest_append <- function(path, record) {
  shard_dir <- .manifest_shard_dir(path)
  dir.create(shard_dir, recursive = TRUE, showWarnings = FALSE)
  stamp <- gsub("[^0-9]", "", format(Sys.time(), "%Y%m%d%H%M%OS6", tz = "UTC"))
  final <- tempfile(pattern = paste0("record-", stamp, "-"),
                    tmpdir = shard_dir, fileext = ".json")
  tmp <- paste0(final, ".tmp")
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  jsonlite::write_json(record, path = tmp, auto_unbox = TRUE, null = "null")
  if (!isTRUE(file.rename(tmp, final))) {
    stop("Could not atomically publish completion manifest record: ", final,
         call. = FALSE)
  }
  .manifest_cache_invalidate(path)
}

#' Read all records from a manifest JSONL file
#'
#' Each line is parsed independently; malformed lines are silently skipped.
#'
#' @param stage_id Character stage identifier.
#' @param config_dir Config directory.
#' @return A list of parsed records (each a list).
#' @keywords internal
.manifest_read <- function(stage_id, config_dir = NULL) {
  path <- .manifest_path(stage_id, config_dir)
  shard_dir <- .manifest_shard_dir(path)
  if (!file.exists(path) && !dir.exists(shard_dir)) return(list())
  cached <- .manifest_cache_get(path)
  if (!is.null(cached)) return(cached)
  records <- list()
  if (file.exists(path)) {
    lines <- readLines(path, warn = FALSE)
    for (line in lines) {
      if (!nzchar(trimws(line))) next
      rec <- tryCatch(
        jsonlite::fromJSON(line, simplifyVector = FALSE),
        error = function(e) NULL
      )
      if (!is.null(rec)) records <- c(records, list(rec))
    }
  }
  if (dir.exists(shard_dir)) {
    shards <- sort(list.files(shard_dir, pattern = "\\.json$", full.names = TRUE))
    for (shard in shards) {
      rec <- tryCatch(jsonlite::read_json(shard, simplifyVector = FALSE),
                      error = function(e) NULL)
      if (!is.null(rec)) records <- c(records, list(rec))
    }
  }
  .manifest_cache_set(path, records)
}

#' Normalize output names for manifest comparisons
#'
#' @param x Character vector, list, or NULL.
#' @return Sorted character vector of output names.
#' @keywords internal
.manifest_output_names <- function(x) {
  if (is.null(x)) return(character())
  vals <- unlist(x, use.names = FALSE)
  vals <- as.character(vals)
  vals <- vals[nzchar(vals)]
  sort(unique(vals))
}

#' Look up an exact-match manifest entry
#'
#' Hashes the provided params and searches for a matching record.
#' If found, verifies that all output files still exist on disk.
#'
#' @param stage_id Character stage identifier.
#' @param params Named list of grid parameters (already cleaned and sorted).
#' @param produces_names Optional character vector of current output names.
#' @param config_dir Config directory.
#' @return The matching record (a list) or \code{NULL}.
#' @keywords internal
.manifest_lookup <- function(stage_id, params, produces_names = NULL, config_dir = NULL) {
  path <- .manifest_path(stage_id, config_dir)
  records <- .manifest_read(stage_id, config_dir)
  if (length(records) == 0L) return(NULL)
  target_hash <- digest::digest(params, algo = "sha1")
  target_identity <- digest::digest(list(version = 2L, params = params), algo = "sha1")
  expected_names <- .manifest_output_names(produces_names)
  candidates <- .manifest_cache_index(path)[[target_hash]]
  if (is.null(candidates)) return(NULL)
  for (rec in rev(candidates)) {
    if (identical(as.integer(rec$param_schema_version), 2L) &&
        identical(rec$param_hash, target_hash) &&
        identical(rec$param_identity, target_identity)) {
      if (length(expected_names) > 0L) {
        recorded_names <- if (!is.null(rec$output_names)) {
          .manifest_output_names(rec$output_names)
        } else {
          sort(names(rec$output_paths) %||% character())
        }
        if (!identical(recorded_names, expected_names)) next
      }
      # Verify all output files still exist
      out_paths <- unlist(rec$output_paths, use.names = TRUE)
      if (all(file.exists(out_paths))) {
        return(rec)
      }
    }
  }
  NULL
}

#' Find manifest entries whose params are a strict subset of current params
#'
#' Used for advisory hints only — never auto-skips. Finds entries whose
#' \code{param_cols} are a strict subset of the current params and whose
#' matching values are identical.
#'
#' @param stage_id Character stage identifier.
#' @param params Named list of grid parameters (already cleaned and sorted).
#' @param config_dir Config directory.
#' @return A list of matching records, or empty list.
#' @keywords internal
.manifest_lookup_subset <- function(stage_id, params, config_dir = NULL) {
  records <- .manifest_read(stage_id, config_dir)
  if (length(records) == 0L) return(list())
  current_cols <- names(params)
  matches <- list()
  seen_hashes <- character()
  for (rec in records) {
    rec_cols <- rec$param_cols
    if (is.null(rec_cols)) next
    rec_cols <- unlist(rec_cols)
    # Must be a strict subset
    if (length(rec_cols) >= length(current_cols)) next
    if (!all(rec_cols %in% current_cols)) next
    # Check matching values
    rec_params <- rec$params
    vals_match <- TRUE
    for (col in rec_cols) {
      rec_val <- rec_params[[col]]
      cur_val <- params[[col]]
      if (!identical(as.character(rec_val), as.character(cur_val))) {
        vals_match <- FALSE
        break
      }
    }
    if (!vals_match) next
    # Verify outputs exist
    out_paths <- unlist(rec$output_paths, use.names = TRUE)
    if (!all(file.exists(out_paths))) next
    # Deduplicate by hash

    if (rec$param_hash %in% seen_hashes) next
    seen_hashes <- c(seen_hashes, rec$param_hash)
    matches <- c(matches, list(rec))
  }
  matches
}

#' Build and append a completion manifest record
#'
#' @param stage_id Character stage identifier.
#' @param params Named list of grid parameters (already cleaned and sorted).
#' @param output_paths Named character vector of output paths.
#' @param script Path to the script that produced outputs.
#' @param config_dir Config directory.
#' @keywords internal
.manifest_record <- function(stage_id, params, output_paths, script = NULL,
                             config_dir = NULL) {
  record <- list(
    stage_id    = stage_id,
    param_schema_version = 2L,
    param_cols  = sort(names(params)),
    params      = params,
    param_hash  = digest::digest(params, algo = "sha1"),
    param_identity = digest::digest(list(version = 2L, params = params), algo = "sha1"),
    output_names = .manifest_output_names(names(output_paths)),
    output_paths = as.list(output_paths),
    completed_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    script       = script
  )
  path <- .manifest_path(stage_id, config_dir)
  .manifest_append(path, record)
  invisible(record)
}

# --- Exported functions -----------------------------------------------------

#' Read a stage's completion manifest
#'
#' Returns the completion manifest for a stage as a tibble. Each row
#' represents a previously completed execution with its parameter values
#' and output paths.
#'
#' @param stage_id Character stage identifier.
#' @param verify Logical; if \code{TRUE}, adds an \code{outputs_current}
#'   column indicating whether all output files still exist on disk.
#' @param config_dir Config directory (defaults to \code{paths_get()$config}).
#' @return A tibble with columns \code{stage_id}, \code{param_hash},
#'   \code{params} (list column), \code{output_paths} (list column),
#'   \code{completed_at}, and optionally \code{outputs_current}.
#' @export
#' @examples
#' \dontrun{
#' # View all completed runs for the "fit" stage
#' completion_manifest("fit")
#'
#' # Verify outputs still exist
#' completion_manifest("fit", verify = TRUE)
#' }
completion_manifest <- function(stage_id, verify = FALSE, config_dir = NULL) {
  records <- .manifest_read(stage_id, config_dir)
  if (length(records) == 0L) {
    cols <- list(
      stage_id = character(),
      param_hash = character(),
      params = list(),
      output_paths = list(),
      completed_at = character()
    )
    if (isTRUE(verify)) cols$outputs_current <- logical()
    return(tibble::as_tibble(cols))
  }
  rows <- lapply(records, function(rec) {
    r <- list(
      stage_id     = rec$stage_id %||% stage_id,
      param_hash   = rec$param_hash %||% NA_character_,
      params       = list(rec$params %||% list()),
      output_paths = list(rec$output_paths %||% list()),
      completed_at = rec$completed_at %||% NA_character_
    )
    if (isTRUE(verify)) {
      out_paths <- unlist(rec$output_paths, use.names = TRUE)
      r$outputs_current <- length(out_paths) > 0L && all(file.exists(out_paths))
    }
    tibble::as_tibble(r)
  })
  do.call(rbind, rows)
}

#' Migrate manifest entries to include new parameters
#'
#' When a new parameter is added to the grid, existing manifest entries
#' lack that column. \code{manifest_adopt} finds entries for a stage whose
#' params are a strict subset of the current schema and appends the new
#' parameter values, writing updated entries so that exact-match lookup
#' succeeds on subsequent runs.
#'
#' @param stage_id Character stage identifier.
#' @param new_params Named list of new parameter names and their values
#'   (e.g., \code{list(cpca = FALSE)}).
#' @param dry_run Logical; if \code{TRUE}, returns a preview of changes
#'   without writing.
#' @param config_dir Config directory (defaults to \code{paths_get()$config}).
#' @return A tibble summarising adopted entries (invisibly, unless
#'   \code{dry_run = TRUE}).
#' @export
#' @examples
#' \dontrun{
#' # After adding a new "cpca" parameter to the grid:
#' manifest_adopt("fit", new_params = list(cpca = FALSE))
#'
#' # Preview without writing
#' manifest_adopt("fit", new_params = list(cpca = FALSE), dry_run = TRUE)
#' }
manifest_adopt <- function(stage_id, new_params, dry_run = FALSE,
                           config_dir = NULL) {
  stopifnot(is.list(new_params), length(new_params) > 0L,
            !is.null(names(new_params)), all(nzchar(names(new_params))))
  records <- .manifest_read(stage_id, config_dir)
  if (length(records) == 0L) {
    message("No manifest entries found for stage '", stage_id, "'")
    return(invisible(tibble::tibble(
      param_hash_old = character(),
      param_hash_new = character(),
      params = list()
    )))
  }

  new_cols <- names(new_params)
  adopted <- list()
  for (rec in records) {
    rec_cols <- unlist(rec$param_cols)
    # Only adopt entries that lack ALL of the new columns
    if (any(new_cols %in% rec_cols)) next
    # Verify outputs still exist
    out_paths <- unlist(rec$output_paths, use.names = TRUE)
    if (!all(file.exists(out_paths))) next

    # Build updated params
    updated_params <- rec$params
    for (nm in new_cols) {
      updated_params[[nm]] <- new_params[[nm]]
    }
    # Sort for deterministic hashing
    updated_params <- updated_params[sort(names(updated_params))]
    new_hash <- digest::digest(updated_params, algo = "sha1")

    adopted <- c(adopted, list(list(
      old_hash = rec$param_hash,
      new_hash = new_hash,
      params   = updated_params,
      output_paths = rec$output_paths,
      script   = rec$script
    )))

    if (!isTRUE(dry_run)) {
      .manifest_record(
        stage_id     = stage_id,
        params       = updated_params,
        output_paths = unlist(rec$output_paths, use.names = TRUE),
        script       = rec$script,
        config_dir   = config_dir
      )
    }
  }

  result <- if (length(adopted) == 0L) {
    tibble::tibble(
      param_hash_old = character(),
      param_hash_new = character(),
      params = list()
    )
  } else {
    tibble::tibble(
      param_hash_old = vapply(adopted, function(a) a$old_hash %||% NA_character_, character(1)),
      param_hash_new = vapply(adopted, function(a) a$new_hash, character(1)),
      params = lapply(adopted, function(a) a$params)
    )
  }

  n <- nrow(result)
  if (n > 0L) {
    action <- if (isTRUE(dry_run)) "Would adopt" else "Adopted"
    message(action, " ", n, " manifest ", if (n == 1L) "entry" else "entries",
            " for stage '", stage_id, "'")
  } else {
    message("No eligible entries to adopt for stage '", stage_id, "'")
  }

  if (isTRUE(dry_run)) result else invisible(result)
}

#' Clear completion manifest for a stage
#'
#' Deletes completion-manifest storage for a stage (or all stages).
#'
#' @param stage_id Character stage identifier, or \code{NULL} to clear all.
#' @param config_dir Config directory (defaults to \code{paths_get()$config}).
#' @return Invisibly returns the path(s) removed.
#' @export
#' @examples
#' \dontrun{
#' # Clear manifest for one stage
#' manifest_clear("fit")
#'
#' # Clear all manifests
#' manifest_clear()
#' }
manifest_clear <- function(stage_id = NULL, config_dir = NULL) {
  config_dir <- config_dir %||% paths_get()$config
  comp_dir <- file.path(config_dir, "completions")
  if (is.null(stage_id)) {
    # Clear all
    files <- list.files(comp_dir, pattern = "\\.jsonl$", full.names = TRUE)
    shard_dirs <- list.files(comp_dir, pattern = "\\.jsonl\\.d$", full.names = TRUE)
    targets <- c(files, shard_dirs)
    if (length(targets) > 0L) {
      unlink(files)
      unlink(shard_dirs, recursive = TRUE)
      .manifest_cache_invalidate()
      message("Cleared ", length(targets), " manifest storage location(s)")
    }
    invisible(targets)
  } else {
    path <- .manifest_path(stage_id, config_dir)
    shard_dir <- .manifest_shard_dir(path)
    if (file.exists(path) || dir.exists(shard_dir)) {
      if (file.exists(path)) unlink(path)
      if (dir.exists(shard_dir)) unlink(shard_dir, recursive = TRUE)
      .manifest_cache_invalidate(path)
      message("Cleared manifest for stage '", stage_id, "'")
    }
    invisible(path)
  }
}
