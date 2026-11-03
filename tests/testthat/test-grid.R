library(testthat)

test_that("grid() adds .grid_id and .grid_hash", {
  params <- grid(x = 1:3, y = c("a", "b"))
  expect_true(".grid_id" %in% names(params))
  expect_true(".grid_hash" %in% names(params))
  expect_equal(params$.grid_id, 1:6)
  expect_length(params$.grid_hash, 6)
  expect_true(all(nchar(params$.grid_hash) == 8))
  expect_true(length(unique(params$.grid_hash)) == 6)
})

test_that("grid filter retains original column types", {
  params <- grid(
    count = 1:3,
    label = c("one", "two", "three"),
    .filter = function(count, label) is.integer(count) && count == 3L && label == "three",
    .add_metadata = FALSE
  )
  expect_equal(params$count, 3L)
  expect_equal(params$label, "three")
})

test_that("grid filter rejects non-logical, non-scalar, and missing results", {
  expect_error(grid(x = 1, .filter = function(x) 1), "one non-missing logical")
  expect_error(grid(x = 1, .filter = function(x) c(TRUE, FALSE)), "one non-missing logical")
  expect_error(grid(x = 1, .filter = function(x) NA), "one non-missing logical")
})

