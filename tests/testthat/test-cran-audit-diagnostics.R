test_that("local jobset failures are reported", {
  job <- structure(
    list(name = "failed", status = "FAILED", kind = "local", result = simpleError("boom")),
    class = c("parade_local_job", "parade_job", "list")
  )
  output <- capture.output(report <- wtf(as_jobset(job), verbose = 0))
  expect_equal(report$n_failed, 1L)
  expect_equal(report$n_ok, 0L)
  expect_match(report$errors[[1]]$detail, "boom")
  expect_false(any(grepl("No failures detected", output, fixed = TRUE)))
})

test_that("failure patterns use stored run events", {
  root <- withr::local_tempdir()
  withr::local_options(parade.paths = list(artifacts = root), parade.event_store = TRUE)
  caravan:::.event_emit("first", "stage_failed", error = "boom")
  caravan:::.event_emit("second", "stage_failed", error = "boom")
  patterns <- failure_patterns("first", "second")
  expect_equal(nrow(patterns), 1L)
  expect_equal(patterns$pattern, "persistent")
  expect_equal(patterns$message, "boom")
})

test_that("failure timeline uses elapsed seconds and orders events", {
  failed <- function(start, end) list(ok = FALSE, skipped = FALSE,
    started_at = start, ended_at = end, duration_ms = 1000, error_message = "boom")
  x <- tibble::tibble(.ok = c(FALSE, FALSE), .diag = list(
    list(later = failed("2026-01-01T00:00:03+0000", "2026-01-01T00:00:04+0000")),
    list(earlier = failed("2026-01-01T00:00:00+0000", "2026-01-01T00:00:01+0000"))
  ))
  attr(x, "parade_run_meta") <- list(started_at = "2026-01-01T00:00:00+0000")
  timeline <- failure_timeline(x)
  expect_equal(timeline$offset, c(1, 4))
  expect_equal(timeline$stage, c("earlier", "later"))
  attr(x, "parade_run_meta") <- NULL
  expect_true(all(is.na(failure_timeline(x)$offset)))
})

test_that("index diagnostics count errors stored as conditions", {
  dir <- withr::local_tempdir()
  result <- tibble::tibble(.diag = list(list(s = list(
    ok = FALSE, skipped = FALSE, error = simpleError("boom"), error_message = "boom"
  ))))
  saveRDS(result, file.path(dir, "index-0001.rds"))
  errors <- caravan:::.read_index_errors(dir)
  expect_equal(errors$n_errors, 1L)
  expect_match(errors$errors, "boom")
})

test_that("temporary scheduler template is effective without persisting", {
  withr::local_options(parade.slurm.template = NULL, parade.config = list())
  template <- tempfile(fileext = ".tmpl")
  writeLines("#!/bin/sh", template)
  on.exit(unlink(template), add = TRUE)
  slurm_template_set(template, persist = FALSE)
  expect_equal(slurm_template_default(), normalizePath(template))
  expect_null(parade_config_read()$slurm$template)
})

test_that("aliases reject a symlink that escapes to a missing descendant", {
  skip_on_os("windows")
  root <- withr::local_tempdir()
  dir.create(file.path(root, "alias"))
  dir.create(file.path(root, "outside"))
  expect_true(file.symlink(file.path(root, "outside"), file.path(root, "alias", "link")))
  withr::local_options(parade.paths = list(data = file.path(root, "alias")),
                       parade.paths.allow_escape = FALSE)
  expect_error(resolve_path("data://link/new/output.rds", create = FALSE), "escapes root")
  expect_false(dir.exists(file.path(root, "outside", "new")))
})

test_that("SLURM mirai passes the requested daemon count to the launcher", {
  skip_if_not_installed("mirai")
  skip_if_not_installed("future.mirai")
  dist <- use_mirai_slurm(n = 7, tls = FALSE)
  expect_equal(dist$remote_n, 7L)
  expect_error(use_mirai_slurm(n = 0), "positive integer")

  submit_backend <- caravan:::.submit_backend_mirai
  called <- NULL
  mockery::stub(submit_backend, ".save_registry_files", function(...) NULL)
  mockery::stub(submit_backend, ".parade_submit_chunk_ids", function(...) integer())
  mockery::stub(submit_backend, "mirai::daemons", function(n, ...) {
    called <<- n
    stop("launcher intercepted")
  })
  expect_error(submit_backend(list(), dist, list(), tempdir(), "index", TRUE, 1),
               "launcher intercepted")
  expect_equal(called, 7L)
})

test_that("script stage restores an existing manifest environment variable", {
  root <- withr::local_tempdir()
  withr::local_envvar(PARADE_MANIFEST = "caller-manifest")
  withr::local_options(parade.paths = list(
    project = root, scratch = root, artifacts = file.path(root, "artifacts"),
    registry = file.path(root, "registry"), config = file.path(root, "config")
  ))
  script <- file.path(root, "script.R")
  writeLines(c('out <- tempfile(fileext = ".rds")',
               'saveRDS(1, out)', 'script_returns(result = out)'), script)
  fl <- flow(data.frame(x = 1L)) |>
    script_stage("run", script = script, produces = "result", engine = "source")
  result <- collect(fl, engine = "sequential")
  expect_true(result$.ok[[1]])
  expect_identical(Sys.getenv("PARADE_MANIFEST", unset = NA_character_), "caller-manifest")
})
