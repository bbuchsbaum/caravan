library(testthat)
library(tibble)

# ============================================================================
# Error surfacing in .eval_row_flow() Tests
# ============================================================================

test_that("propagate error policy emits message on stage failure", {
  grid <- data.frame(x = 1:4)
  fl <- flow(grid, error = "propagate") |>
    stage("s", function(x) {
      if (x == 3) stop("boom")
      list(y = as.double(x^2))
    }, schema = returns(y = dbl()))

  msgs <- character()
  res <- withCallingHandlers(
    collect(fl, engine = "sequential"),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )

  expect_equal(nrow(res), 4)
  expect_false(res$.ok[3])
  # Should have emitted a message about the failure
  parade_msgs <- grep("\\[parade\\]", msgs, value = TRUE)
  expect_true(any(grepl("Stage 's' failed", parade_msgs)))
  expect_true(any(grepl("boom", parade_msgs)))
})

test_that("keep error policy emits message on stage failure", {
  grid <- data.frame(x = 1:3)
  fl <- flow(grid, error = "keep") |>
    stage("s", function(x) {
      if (x == 2) stop("kaboom")
      list(y = as.double(x))
    }, schema = returns(y = dbl()))

  msgs <- character()
  res <- withCallingHandlers(
    collect(fl, engine = "sequential"),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )

  expect_equal(nrow(res), 3)
  expect_false(res$.ok[2])
  parade_msgs <- grep("\\[parade\\]", msgs, value = TRUE)
  expect_true(any(grepl("Stage 's' failed", parade_msgs)))
  expect_true(any(grepl("kaboom", parade_msgs)))
})

test_that("stop error policy does NOT emit extra message", {
  grid <- data.frame(x = 1:3)
  fl <- flow(grid, error = "stop") |>
    stage("s", function(x) {
      if (x == 2) stop("direct_error")
      list(y = as.double(x))
    }, schema = returns(y = dbl()))

  # "stop" should throw, not emit message
  expect_error(collect(fl, engine = "sequential"), "direct_error")
})

# ============================================================================
# Error surfacing in .parade_execute_chunk() Tests
# ============================================================================

test_that("chunk with errors causes stop after saving index", {
  root <- withr::local_tempdir("caravan-collect-errors-")
  old_paths <- getOption("parade.paths")
  on.exit(options(parade.paths = old_paths), add = TRUE)
  paths_init(quiet = TRUE)
  paths_set(
    scratch = root,
    artifacts = file.path(root, "artifacts"),
    registry = file.path(root, "registry")
  )

  grid <- data.frame(x = 1:4, group = rep(c("A", "B"), 2))
  fl <- flow(grid, error = "propagate") |>
    stage("s", function(x) {
      if (x == 3) stop("boom")
      list(y = as.double(x^2))
    }, schema = returns(y = dbl())) |>
    distribute(dist_local(by = "group"))

  d <- submit(fl, clean = TRUE)
  # Wait and catch the error from the chunk that had failures
  # The local backend should propagate the error
  tryCatch(deferred_await(d, timeout = 30), error = function(e) NULL)

  # Index files should still be saved despite the error
  idx_dir <- resolve_path(d$index_dir)
  files <- list.files(idx_dir, pattern = "\\.rds$", full.names = TRUE)
  expect_true(length(files) > 0)

  # We should be able to collect partial results
  res <- deferred_collect(d)
  expect_true(nrow(res) > 0)
})

test_that("collect rejects deferred-only distribution backends and modes", {
  fl <- flow(tibble::tibble(x = 1L)) |>
    stage("id", function(x) list(y = x), schema = returns(y = int()))

  expect_error(
    collect(distribute(fl, dist_slurm()), engine = "sequential"),
    "only executes local distributions"
  )
  expect_error(
    collect(distribute(fl, dist_local(within = "callr")), engine = "sequential"),
    "does not implement within = 'callr'"
  )
})

test_that("ungrouped future collect honors a worker request and restores the plan", {
  old_plan <- future::plan(future::sequential)
  on.exit(future::plan(old_plan), add = TRUE)
  fl <- flow(tibble::tibble(x = 1:2)) |>
    stage("pid", function(x) list(value = x), schema = returns(value = int()))

  out <- collect(fl, engine = "future", workers = 1L, .progress = FALSE)
  expect_equal(out$pid.value, 1:2)
  expect_true(inherits(future::plan(), "FutureStrategy"))
  expect_match(paste(class(future::plan()), collapse = " "), "sequential")
})
