# Jobset: status + results + monitoring --------------------------------------

#' Get status of all jobs in a jobset
#'
#' @param x A `parade_jobset` object
#' @param ... Additional arguments passed to method implementations
#' @return A tibble with job status information
#' @examples
#' \dontrun{
#' jobs <- slurm_map(1:4, function(x) x^2)
#' status(jobs)
#' }
#' @export
status <- function(x, ...) {
  UseMethod("status")
}

#' @export
status.parade_jobset <- function(x, ...) {
  if (length(x) == 0) {
    return(tibble::tibble(
      index = integer(),
      name = character(),
      state = character(),
      kind = character()
    ))
  }

  statuses <- lapply(seq_along(x), function(i) {
    job <- x[[i]]
    s <- job_status(job)
    s$index <- i
    s
  })

  do.call(rbind, statuses)
}

#' @export
status.parade_job <- function(x, ...) {
  job_status(x)
}

#' Collect results from all jobs in a jobset
#'
#' @param x A `parade_jobset` object
#' @param ... Additional arguments passed to method implementations
#' @return List or simplified structure of results
#' @examples
#' \dontrun{
#' jobs <- slurm_map(1:4, function(x) x^2)
#' await(jobs)
#' results <- collect(jobs)
#' }
#' @export
collect <- function(x, ...) {
  UseMethod("collect")
}

#' @rdname collect
#' @param simplify Try to simplify results into a vector/matrix (default: TRUE)
#' @export
collect.parade_jobset <- function(x, simplify = TRUE, ...) {
  if (length(x) == 0) return(list())

  is_packed <- isTRUE(attr(x, "is_packed"))

  if (is_packed) {
    chunk_results <- lapply(x, collect_result)

    all_results <- list()
    for (chunk_res in chunk_results) {
      if (inherits(chunk_res, "parade_packed_result")) {
        all_results <- c(all_results, unclass(chunk_res))
      } else if (is.list(chunk_res)) {
        all_results <- c(all_results, chunk_res)
      } else {
        all_results <- c(all_results, list(chunk_res))
      }
    }

    results <- all_results
  } else {
    results <- lapply(x, collect_result)
  }

  if (isTRUE(simplify) && length(results) > 0) {
    if (all(vapply(results, is.null, logical(1)))) {
      return(NULL)
    }

    if (all(vapply(results, is.data.frame, logical(1)))) {
      return(do.call(rbind, results))
    }

    types <- vapply(results, typeof, character(1))
    if (length(unique(types)) == 1 && all(vapply(results, is.atomic, logical(1)))) {
      return(unlist(results))
    }
  }

  results
}

#' @export
collect.parade_job <- function(x, ...) {
  collect_result(x)
}

#' Cancel all jobs in a jobset
#'
#' @param x A `parade_jobset` object
#' @param ... Additional arguments passed to method implementations
#' @return The jobset (invisibly)
#' @examples
#' \dontrun{
#' jobs <- slurm_map(1:4, function(x) Sys.sleep(100))
#' cancel(jobs)
#' }
#' @export
cancel <- function(x, ...) {
  UseMethod("cancel")
}

#' @export
cancel.parade_jobset <- function(x, ...) {
  for (job in x) {
    if (inherits(job, "parade_script_job")) {
      tryCatch(
        script_cancel(job),
        error = function(e) {
          warning("Failed to cancel job ", job$name, ": ", e$message)
        }
      )
    }
  }
  invisible(x)
}

#' @export
cancel.parade_job <- function(x, ...) {
  if (inherits(x, "parade_script_job")) {
    script_cancel(x)
  }
  invisible(x)
}

#' Get tail of logs for jobs
#'
#' @param x A parade_jobset or parade_job
#' @param n Number of lines to show
#' @param ... Additional arguments
#' @return Character vector of log lines (invisibly)
#'
#' @examples
#' \dontrun{
#' jobs <- slurm_map(1:4, function(x) x^2)
#' tail(jobs, n = 20)
#' }
#'
#' @importFrom utils tail
#' @export
tail.parade_jobset <- function(x, n = 50, ...) {
  if (length(x) == 0) return(invisible(character()))

  for (job in x) {
    if (inherits(job, "parade_script_job")) {
      logs <- tryCatch(
        script_tail(job, n = n),
        error = function(e) NULL
      )
      if (!is.null(logs) && length(logs) > 0) {
        cat("Logs from job:", job$name %||% "(unnamed)", "\n")
        cat(logs, sep = "\n")
        return(invisible(logs))
      }
    }
  }

  message("No logs available from any jobs")
  invisible(character())
}

#' Launch interactive monitor for jobset
#'
#' @param x A parade_jobset or parade_job object
#' @param ... Additional arguments passed to methods
#' @return NULL (invisibly)
#' @examples
#' \dontrun{
#' jobs <- slurm_map(1:4, function(x) Sys.sleep(60))
#' top(jobs)
#' }
#' @export
top <- function(x, ...) {
  UseMethod("top")
}

#' @rdname top
#' @param refresh Refresh interval in seconds (default: 2)
#' @param nlog Number of log lines to show (default: 20)
#' @export
top.parade_jobset <- function(x, refresh = 2, nlog = 20, ...) {
  if (length(x) == 0) {
    message("No jobs to monitor")
    return(invisible(NULL))
  }

  if (length(x) > 1 && exists("jobs_top", mode = "function")) {
    jobs_top(x, refresh = refresh, nlog = nlog)
  } else if (length(x) == 1) {
    if (inherits(x[[1]], "parade_script_job")) {
      script_top(x[[1]], refresh = refresh, nlog = nlog)
    }
  } else {
    message("Monitoring not available for this jobset")
  }

  invisible(NULL)
}

#' @rdname top
#' @param refresh Refresh interval in seconds (default: 2)
#' @param nlog Number of log lines to show (default: 30)
#' @export
top.parade_job <- function(x, refresh = 2, nlog = 30, ...) {
  if (inherits(x, "parade_script_job")) {
    script_top(x, refresh = refresh, nlog = nlog)
  } else {
    message("Monitoring not available for this job type")
  }
  invisible(NULL)
}

#' Extract subset of jobs
#'
#' @param x A parade_jobset object
#' @param i Index vector for subsetting
#' @return A \code{parade_jobset} containing the selected jobs.
#'
#' @examples
#' \dontrun{
#' jobs <- slurm_map(1:4, function(x) x^2)
#' first_two <- jobs[1:2]
#' }
#'
#' @export
`[.parade_jobset` <- function(x, i) {
  out <- NextMethod("[")
  attrs <- attributes(x)
  keep <- setdiff(names(attrs), c("names", "class"))
  for (nm in keep) attr(out, nm) <- attrs[[nm]]
  if (isTRUE(attr(x, "is_packed"))) {
    chunk_counts <- vapply(out, function(job) length(job$.__chunk_indices__ %||% integer()),
                           integer(1))
    if (length(chunk_counts) && all(chunk_counts > 0L)) {
      attr(out, "n_elements") <- sum(chunk_counts)
    }
  }
  class(out) <- c("parade_jobset", "list")
  out
}

#' Combine jobsets
#'
#' @param ... parade_jobset objects to combine
#' @return A combined \code{parade_jobset} object.
#'
#' @examples
#' \dontrun{
#' jobs1 <- slurm_map(1:2, function(x) x^2)
#' jobs2 <- slurm_map(3:4, function(x) x^2)
#' combined <- c(jobs1, jobs2)
#' }
#'
#' @export
c.parade_jobset <- function(...) {
  inputs <- list(...)
  jobs <- unlist(inputs, recursive = FALSE, use.names = TRUE)
  packed <- vapply(inputs, function(x) isTRUE(attr(x, "is_packed")), logical(1))
  attrs <- list(class = c("parade_jobset", "list"), timestamp = Sys.time())
  if (length(inputs) && all(packed)) {
    # Preserve the packed contract only when all chunks came from packed
    # jobsets. Mixing packed and ordinary jobs has no single element mapping.
    first <- inputs[[1L]]
    attrs$is_packed <- TRUE
    for (nm in c("map_call", "error_policy", "chunk_size", "workers_per_node",
                 "packed_log_root", "chunk_results_root", "parallel_backend",
                 "capture_child_io")) {
      value <- attr(first, nm, exact = TRUE)
      if (!is.null(value)) attrs[[nm]] <- value
    }
    n_elements <- vapply(inputs, function(x) attr(x, "n_elements", exact = TRUE) %||% 0L,
                         integer(1))
    attrs$n_elements <- sum(n_elements)
  }
  attributes(jobs) <- c(attributes(jobs), attrs)
  jobs
}

#' Get length of jobset
#'
#' @param x A parade_jobset object
#' @return Integer; the number of jobs in the set.
#'
#' @examples
#' \dontrun{
#' jobs <- slurm_map(1:4, function(x) x^2)
#' length(jobs)
#' }
#'
#' @export
length.parade_jobset <- function(x) {
  NextMethod("length")
}

#' Convert jobset to tibble
#'
#' @param x A parade_jobset object
#' @param ... Additional arguments (unused)
#' @return A [tibble::tibble()] with one row per job.
#'
#' @examples
#' \dontrun{
#' jobs <- slurm_map(1:4, function(x) x^2)
#' tibble::as_tibble(jobs)
#' }
#'
#' @importFrom tibble as_tibble
#' @export
as_tibble.parade_jobset <- function(x, ...) {
  if (length(x) == 0) {
    return(tibble::tibble(
      index = integer(),
      name = character(),
      state = character(),
      kind = character()
    ))
  }

  status(x)
}
