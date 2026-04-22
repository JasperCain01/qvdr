# tests/testthat/test-type-coercion.R
# ---------------------------------------------------------------------------
# Tests for type coercion: dates, timestamps, numeric types, dual values
# ---------------------------------------------------------------------------

test_that("integer columns are returned as integer type", {
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path))
  df <- data.frame(X = 1L:10L)
  qvdr:::write_test_qvd(df, path)
  result <- read_qvd(path, verbose = FALSE)
  expect_type(result$X, "integer")
})

test_that("double columns are returned as double type", {
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path))
  df <- data.frame(X = c(1.1, 2.2, 3.3))
  qvdr:::write_test_qvd(df, path)
  result <- read_qvd(path, verbose = FALSE)
  expect_type(result$X, "double")
})

test_that("character columns are returned as character type", {
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path))
  df <- data.frame(X = c("foo", "bar", "baz"), stringsAsFactors = FALSE)
  qvdr:::write_test_qvd(df, path)
  result <- read_qvd(path, verbose = FALSE)
  expect_type(result$X, "character")
})

test_that("int_as_int = FALSE returns double for integer columns", {
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path))
  df <- data.frame(X = 1L:5L)
  qvdr:::write_test_qvd(df, path)
  result <- read_qvd(path, int_as_int = FALSE, verbose = FALSE)
  expect_type(result$X, "double")
})

test_that("integer values survive round-trip", {
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path))
  vals <- c(-1000L, -1L, 0L, 1L, 42L, 1000L, .Machine$integer.max %/% 2L)
  df <- data.frame(X = vals)
  qvdr:::write_test_qvd(df, path)
  result <- read_qvd(path, verbose = FALSE)
  expect_equal(as.integer(result$X), vals)
})

test_that("double values survive round-trip", {
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path))
  vals <- c(-1e10, -0.001, 0.0, 1.23456789, 1e10)
  df <- data.frame(X = vals)
  qvdr:::write_test_qvd(df, path)
  result <- read_qvd(path, verbose = FALSE)
  expect_equal(as.double(result$X), vals, tolerance = 1e-9)
})

test_that("string values with special characters survive round-trip", {
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path))
  vals <- c("Hello World", "foo/bar", "100%", "value=1", "")
  df <- data.frame(X = vals, stringsAsFactors = FALSE)
  qvdr:::write_test_qvd(df, path)
  result <- read_qvd(path, verbose = FALSE)
  expect_equal(as.character(result$X), vals)
})

test_that("mixed integer and NA survive round-trip", {
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path))
  vals <- c(1L, NA_integer_, 3L, NA_integer_, 5L)
  df <- data.frame(X = vals)
  qvdr:::write_test_qvd(df, path)
  result <- read_qvd(path, verbose = FALSE)
  expect_equal(is.na(result$X), is.na(vals))
  expect_equal(as.integer(result$X[!is.na(result$X)]),
               vals[!is.na(vals)])
})

test_that("all-NA column returns all NA", {
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path))
  df <- data.frame(X = c(NA_character_, NA_character_, NA_character_),
                   stringsAsFactors = FALSE)
  qvdr:::write_test_qvd(df, path)
  result <- read_qvd(path, verbose = FALSE)
  expect_true(all(is.na(result$X)))
})

test_that("columns with one unique value work", {
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path))
  df <- data.frame(X = rep("constant", 10L), stringsAsFactors = FALSE)
  qvdr:::write_test_qvd(df, path)
  result <- read_qvd(path, verbose = FALSE)
  expect_equal(unique(as.character(result$X)), "constant")
  expect_equal(nrow(result), 10L)
})

test_that("columns with high cardinality (many symbols) work", {
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path))
  n <- 1000L
  df <- data.frame(X = seq_len(n), stringsAsFactors = FALSE)
  qvdr:::write_test_qvd(df, path)
  result <- read_qvd(path, verbose = FALSE)
  expect_equal(nrow(result), n)
  expect_equal(sort(as.integer(result$X)), seq_len(n))
})

test_that("multiple columns all survive round-trip correctly", {
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path))
  set.seed(1L)
  n <- 50L
  df <- data.frame(
    IntCol  = sample(1L:100L, n, replace = TRUE),
    DblCol  = round(runif(n), 4),
    StrCol  = sample(letters, n, replace = TRUE),
    stringsAsFactors = FALSE
  )
  qvdr:::write_test_qvd(df, path)
  result <- read_qvd(path, verbose = FALSE)

  expect_equal(as.integer(result$IntCol), df$IntCol)
  expect_equal(as.double(result$DblCol),  df$DblCol,  tolerance = 1e-6)
  expect_equal(as.character(result$StrCol), df$StrCol)
})
