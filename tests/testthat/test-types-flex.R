library(testthat)

test_that("caravan::isa() creates proper type objects", {
  # Test with basic classes
  spec <- caravan::isa("data.frame")
  expect_s3_class(spec, "parade_ptype_class")
  expect_equal(spec$class, "data.frame")
  
  # Multiple classes
  spec_multi <- caravan::isa(c("tbl_df", "data.frame"))
  expect_s3_class(spec_multi, "parade_ptype_class")
  expect_equal(spec_multi$class, c("tbl_df", "data.frame"))
})

test_that("caravan::blob() creates proper type objects", {
  # caravan::blob() without class accepts anything
  spec_any <- caravan::blob()
  expect_s3_class(spec_any, "parade_ptype_any")
  
  # caravan::blob() with class requirement
  spec_lm <- caravan::blob(class = "lm")
  expect_s3_class(spec_lm, "parade_ptype_class")
  expect_equal(spec_lm$class, "lm")
})

test_that("caravan::maybe() creates proper type objects", {
  spec <- caravan::maybe(caravan::isa("lm"))
  expect_s3_class(spec, "parade_ptype_maybe")
  expect_s3_class(spec$spec, "parade_ptype_class")
})

test_that("caravan::one_of() creates proper type objects", {
  spec <- caravan::one_of(caravan::isa("lm"), caravan::isa("glm"), caravan::isa("data.frame"))
  expect_s3_class(spec, "parade_ptype_union")
  expect_length(spec$types, 3)
})

test_that("caravan::pred() creates proper type objects", {
  # Light predicate
  spec_light <- caravan::pred(~ length(.) > 0, cost = "light")
  expect_s3_class(spec_light, "parade_ptype_pred")
  expect_equal(spec_light$cost, "light")
  
  # Heavy predicate
  spec_heavy <- caravan::pred(~ sum(.) > 10, cost = "full")
  expect_s3_class(spec_heavy, "parade_ptype_pred")
  expect_equal(spec_heavy$cost, "full")
  
  # Function syntax (not formula)
  spec_fn <- caravan::pred(function(x) is.numeric(x) && all(x > 0), cost = "light")
  expect_s3_class(spec_fn, "parade_ptype_pred")
  expect_equal(spec_fn$cost, "light")
})

test_that("pred(timeout=) limits long-running predicates", {
  if (.Platform$OS.type == "windows") {
    skip("pred(timeout=) uses best-effort time limits on Windows; skip timing-sensitive test")
  }
  spec <- caravan::pred(function(x) { Sys.sleep(2); TRUE }, timeout = 0.2)
  start <- Sys.time()
  ok <- caravan:::.parade_check_type(1, spec, mode = "full")
  elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs"))

  expect_false(ok)
  expect_lt(elapsed, 2)
  expect_silent(Sys.sleep(0.05))
})

test_that("pred(timeout=) validates inputs", {
  expect_error(caravan::pred(function(x) TRUE, timeout = 0), "positive")
  expect_error(caravan::pred(function(x) TRUE, timeout = -1), "positive")
  expect_error(caravan::pred(function(x) TRUE, timeout = NA_real_), "positive")
})

test_that("caravan::neurovol() creates proper type objects", {
  # Basic neurovol
  spec <- caravan::neurovol()
  expect_s3_class(spec, "parade_ptype_class")
  expect_equal(spec$class, "neuroim2::NeuroVol")
  
  # With specific class
  spec_logical <- caravan::neurovol(class = "LogicalNeuroVol")
  expect_equal(spec_logical$class, "LogicalNeuroVol")
  
  # With dimension check (creates combined spec)
  spec_dims <- caravan::neurovol(dims = c(91, 109, 91))
  expect_s3_class(spec_dims, "parade_ptype_combined")
  expect_length(spec_dims$specs, 2)
  
  # maybe_neurovol convenience
  spec_maybe <- caravan::maybe_neurovol()
  expect_s3_class(spec_maybe, "parade_ptype_maybe")
  expect_s3_class(spec_maybe$spec, "parade_ptype_class")
})

test_that("caravan:::is_flex_type identifies flexible types", {
  expect_true(caravan:::is_flex_type(caravan::isa("lm")))
  expect_true(caravan:::is_flex_type(caravan::blob()))
  expect_true(caravan:::is_flex_type(caravan::maybe(caravan::isa("lm"))))
  expect_true(caravan:::is_flex_type(caravan::one_of(caravan::isa("lm"), caravan::isa("glm"))))
  expect_true(caravan:::is_flex_type(caravan::pred(~ length(.) > 0)))
  expect_true(caravan:::is_flex_type(caravan::neurovol()))
  
  # Not flex types
  expect_false(caravan:::is_flex_type(caravan::dbl()))
  expect_false(caravan:::is_flex_type(caravan::chr()))
  expect_false(caravan:::is_flex_type(list(x = 1)))
  expect_false(caravan:::is_flex_type(NULL))
})

test_that("Combined specs create proper structure", {
  # Create a combined spec manually
  spec <- structure(
    list(specs = list(
      caravan::isa("data.frame"),
      caravan::pred(~ nrow(.) > 2, cost = "light")
    )),
    class = "parade_ptype_combined"
  )
  
  expect_s3_class(spec, "parade_ptype_combined")
  expect_length(spec$specs, 2)
})

test_that("one_of validates standard vctrs prototypes", {
  spec <- caravan::one_of(caravan::dbl(), caravan::chr())
  expect_true(caravan:::.parade_check_type(1L, spec, mode = "full"))
  expect_true(caravan:::.parade_check_type("one", spec, mode = "full"))
  expect_false(caravan:::.parade_check_type(list(one = 1), spec, mode = "full"))
})

# Note: Validation behavior is tested through integration tests in test-flexible-integration.R
# where the .parade_check_type function is properly called within the package context
