library(testthat)
library(caravan)

local({
  # Keep tests that exercise default scratch paths inside R's own temporary
  # directory. Individual tests can still override TMPDIR to test path selection.
  old_tmpdir <- Sys.getenv("TMPDIR", unset = NA_character_)
  on.exit({
    if (is.na(old_tmpdir)) Sys.unsetenv("TMPDIR")
    else Sys.setenv(TMPDIR = old_tmpdir)
  }, add = TRUE)
  scratch <- tempfile("caravan-tests-", tmpdir = tempdir())
  dir.create(scratch)
  Sys.setenv(TMPDIR = scratch)
  test_check("caravan")
})
