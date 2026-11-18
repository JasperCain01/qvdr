# tests/testthat/test-type-coercion.R
# ---------------------------------------------------------------------------
# Column types and value fidelity for each symbol type, plus the two
# type-control arguments. expect_identical() is used throughout so that a
# value read back as the wrong type fails, rather than being hidden by an
# as.integer() / as.character() wrapper. See tests/TESTS.md.
# ---------------------------------------------------------------------------

round_trip <- function(df) {
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path))
  qvdr:::write_test_qvd(df, path)
  read_qvd(path, verbose = FALSE)
}

test_that("integers come back as integers with their exact values, including negatives", {
  vals <- c(-1000L, -1L, 0L, 1L, 42L, 1000L, .Machine$integer.max %/% 2L)
  expect_identical(round_trip(data.frame(X = vals))$X, vals)
})

test_that("doubles come back as doubles with their exact values, across magnitudes", {
  vals <- c(-1e10, -0.001, 0.0, 1.23456789, 1e10)
  expect_identical(round_trip(data.frame(X = vals))$X, vals)
})

test_that("strings come back as character, with special characters and the empty string intact", {
  vals <- c("Hello World", "foo/bar", "100%", "value=1", "")
  expect_identical(round_trip(data.frame(X = vals, stringsAsFactors = FALSE))$X, vals)
})

test_that("int_as_int = FALSE returns double for integer columns", {
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path))
  qvdr:::write_test_qvd(data.frame(X = 1L:5L), path)
  expect_identical(read_qvd(path, int_as_int = FALSE, verbose = FALSE)$X, as.double(1:5))
})

test_that("numeric_as_num = FALSE returns every column as character", {
  fix <- make_numeric_qvd()
  on.exit(unlink(fix$path))
  result <- read_qvd(fix$path, numeric_as_num = FALSE, verbose = FALSE)
  expect_true(all(vapply(result, is.character, logical(1))))
})
