test_that("script runners restore environment and library state", {
  td <- withr::local_tempdir("parade-runner-state-")
  script <- file.path(td, "script.R")
  writeLines("invisible(NULL)", script)
  unset_name <- "PARADE_TEST_RUNNER_UNSET"
  empty_name <- "PARADE_TEST_RUNNER_EMPTY"
  Sys.unsetenv(unset_name)
  Sys.setenv(PARADE_TEST_RUNNER_EMPTY = "")
  old_lib_paths <- .libPaths()
  on.exit({
    Sys.unsetenv(unset_name)
    Sys.setenv(PARADE_TEST_RUNNER_EMPTY = "")
    .libPaths(old_lib_paths)
  }, add = TRUE)

  env <- c("changed", "changed")
  names(env) <- c(unset_name, empty_name)
  result <- parade_run_script_bt(
    i = 1L, script = script, args = character(), env = env,
    lib_paths = td, rscript = file.path(R.home("bin"), "Rscript"), wd = td
  )
  expect_true(result$ok)
  expect_true(is.na(Sys.getenv(unset_name, unset = NA_character_)))
  expect_identical(Sys.getenv(empty_name, unset = NA_character_), "")
  expect_identical(.libPaths(), old_lib_paths)

  local <- submit_script_local(script, env = env, lib_paths = td, wd = td)
  expect_identical(local$status, "COMPLETED")
  expect_true(is.na(Sys.getenv(unset_name, unset = NA_character_)))
  expect_identical(Sys.getenv(empty_name, unset = NA_character_), "")
  expect_identical(.libPaths(), old_lib_paths)
})

test_that("system2 argument quoting delegates to the current platform", {
  args <- c("path with spaces", "quote\"and\\backslash", "semi;colon")
  expect_identical(.parade_system2_args(args), shQuote(args))
})
