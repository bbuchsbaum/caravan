testthat::skip_if_not_installed("batchtools")

make_reload_test_cluster_functions <- function(marker) {
  batchtools::makeClusterFunctions(
    "parade-reload-test",
    submitJob = function(reg, jc) batchtools:::makeSubmitJobResult(0L, "123"),
    killJob = function(reg, batch.id) writeLines(as.character(batch.id), marker),
    listJobsQueued = function(reg) "123",
    listJobsRunning = function(reg) character()
  )
}

test_that("Parade restores persisted cluster functions before registry sync", {
  registry_dir <- file.path(withr::local_tempdir("parade-batchtools-reload-"), "registry")
  marker <- tempfile("parade-batchtools-kill-")
  cf <- make_reload_test_cluster_functions(marker)

  reg <- bt_make_registry(registry_dir, cf)
  batchtools::batchMap(function(i) i, i = 1L, reg = reg)
  batchtools::submitJobs(reg = reg)

  reloaded <- bt_load_registry(registry_dir, writeable = TRUE)
  expect_identical(reloaded$cluster.functions$name, "parade-reload-test")
  expect_equal(nrow(batchtools::findQueued(reg = reloaded)), 1L)

  job <- structure(
    list(registry_dir = registry_dir, job_id = 1L, name = "reload-test"),
    class = c("parade_script_job", "parade_job")
  )
  script_cancel(job)
  expect_true(file.exists(marker))
  expect_identical(readLines(marker), "123")
})

test_that("Parade refuses a registry without saved backend metadata", {
  registry_dir <- file.path(withr::local_tempdir("parade-batchtools-legacy-"), "registry")
  batchtools::makeRegistry(
    file.dir = registry_dir,
    make.default = FALSE,
    conf.file = NA
  )

  expect_error(
    bt_load_registry(registry_dir),
    "no Parade cluster-functions metadata"
  )
})
