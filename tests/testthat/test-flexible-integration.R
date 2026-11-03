library(testthat)

test_that("flexible types integrate with caravan::collect()", {
  skip_if_not_installed("tibble")
  
  # Test with caravan::isa() validation
  grid <- data.frame(x = 1:3, seed = 100:102)  # Add seed for reproducibility
  
  fl <- caravan::flow(grid, seed_col = "seed") |>
    caravan::stage(
      id = "fit",
      f = function(x) {
        model <- lm(y ~ x, data = data.frame(x = 1:x, y = rnorm(x)))
        list(model = model)
      },
      schema = caravan::returns(model = caravan::isa("lm"))
    )
  
  # Light validation (default)
  results <- caravan::collect(fl, engine = "sequential")
  expect_s3_class(results, "tbl_df")
  expect_equal(nrow(results), 3)
  expect_true(all(results$.ok))
  # Column is prefixed with stage id
  expect_s3_class(results$fit.model[[1]], "lm")
  
  # Full validation - use same seed for consistency
  fl_full <- caravan::flow(grid, seed_col = "seed") |>
    caravan::stage(
      id = "fit",
      f = function(x) {
        model <- lm(y ~ x, data = data.frame(x = 1:x, y = rnorm(x)))
        list(model = model)
      },
      schema = caravan::returns(model = caravan::isa("lm"))
    )
  
  results_full <- caravan::collect(fl_full, engine = "sequential", validate = "full")
  # Check both have same structure rather than exact equality
  expect_equal(nrow(results), nrow(results_full))
  expect_true(all(results_full$.ok))
})

test_that("flexible types catch validation errors", {
  skip_if_not_installed("tibble")
  
  grid <- data.frame(x = 1:2)
  
  # Stage returns wrong type
  fl <- caravan::flow(grid, error = "keep") |>
    caravan::stage(
      id = "wrong",
      f = function(x) {
        list(model = data.frame(x = 1:x))  # Returns data.frame, not lm
      },
      schema = caravan::returns(model = caravan::isa("lm"))
    )
  
  results <- caravan::collect(fl, engine = "sequential")
  expect_false(all(results$.ok))
})

test_that("caravan::maybe() allows NULL values", {
  skip_if_not_installed("tibble")
  
  grid <- data.frame(x = c(5, 2))
  
  fl <- caravan::flow(grid) |>
    caravan::stage(
      id = "conditional",
      f = function(x) {
        # Only fit model if x > 3
        model <- if (x > 3) {
          lm(y ~ x, data = data.frame(x = 1:x, y = rnorm(x)))
        } else {
          NULL
        }
        list(model = model, x = x)
      },
      schema = caravan::returns(
        model = caravan::maybe(caravan::isa("lm")),
        x = caravan::int()
      )
    )
  
  results <- caravan::collect(fl, engine = "sequential")
  expect_true(all(results$.ok))
  expect_s3_class(results$conditional.model[[1]], "lm")  # x=5, should have model
  expect_null(results$conditional.model[[2]])  # x=2, should be NULL
})

test_that("caravan::pred() respects validation modes", {
  skip_if_not_installed("tibble")
  
  grid <- data.frame(x = c(10, 5))
  
  fl <- caravan::flow(grid) |>
    caravan::stage(
      id = "check",
      f = function(x) {
        list(
          data = 1:x,
          sum = sum(1:x)
        )
      },
      schema = caravan::returns(
        data = caravan::pred(~ length(.) > 3, cost = "light"),  # Always runs
        sum = caravan::pred(~ . > 20, cost = "full")  # Only in full mode
      )
    )
  
  # Light mode - only checks length
  results_light <- caravan::collect(fl, engine = "sequential", validate = "light")
  expect_true(all(results_light$.ok))  # Both pass length check
  
  # Full mode - checks both predicates
  fl_full <- caravan::flow(grid, error = "keep") |>
    caravan::stage(
      id = "check",
      f = function(x) {
        list(
          data = 1:x,
          sum = sum(1:x)
        )
      },
      schema = caravan::returns(
        data = caravan::pred(~ length(.) > 3, cost = "light"),  # Always runs
        sum = caravan::pred(~ . > 20, cost = "full")  # Only in full mode
      )
    )
  
  results_full <- caravan::collect(fl_full, engine = "sequential", validate = "full")
  expect_false(results_full$.ok[2])  # x=5: sum=15, fails >20 check
})