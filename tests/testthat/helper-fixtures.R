# tests/testthat/helper-fixtures.R
# ---------------------------------------------------------------------------
# Create synthetic QVD fixture files used across the test suite.
# All fixture files are written to a temp directory and cleaned up after
# each test session.
# ---------------------------------------------------------------------------

#' Create a simple integer + string QVD fixture
#' @keywords internal
make_simple_qvd <- function(path = tempfile(fileext = ".qvd")) {
  df <- data.frame(
    ID     = 1L:5L,
    Name   = c("Alice", "Bob", "Charlie", "Diana", "Eve"),
    Score  = c(88L, 72L, 95L, 60L, 81L),
    stringsAsFactors = FALSE
  )
  qvdr:::write_test_qvd(df, path, table_name = "SimpleTest")
  list(path = path, data = df)
}

#' Create a QVD with numeric (double) columns
#' @keywords internal
make_numeric_qvd <- function(path = tempfile(fileext = ".qvd")) {
  df <- data.frame(
    SalesID = 1L:10L,
    Amount  = c(100.5, 200.0, 300.75, 150.25, 500.0,
                 50.0,  99.9, 1234.56, 0.01, 9999.99),
    Tax     = c(20.1, 40.0, 60.15, 30.05, 100.0,
                10.0, 19.98, 246.91,  0.002, 1999.998),
    stringsAsFactors = FALSE
  )
  qvdr:::write_test_qvd(df, path, table_name = "NumericTest")
  list(path = path, data = df)
}

#' Create a QVD with NULL/NA values
#' @keywords internal
make_na_qvd <- function(path = tempfile(fileext = ".qvd")) {
  df <- data.frame(
    ID      = c(1L, 2L, 3L, 4L, 5L),
    Label   = c("A", NA, "C", NA, "E"),
    Value   = c(10L, NA, 30L, NA, 50L),
    stringsAsFactors = FALSE
  )
  qvdr:::write_test_qvd(df, path, table_name = "NaTest")
  list(path = path, data = df)
}

#' Create a large QVD fixture for performance benchmarks
#' @keywords internal
make_large_qvd <- function(n = 100000L,
                            path = tempfile(fileext = ".qvd")) {
  set.seed(42L)
  df <- data.frame(
    ID       = seq_len(n),
    Region   = sample(c("North", "South", "East", "West"), n, replace = TRUE),
    Category = sample(LETTERS[1:10], n, replace = TRUE),
    Amount   = round(runif(n, 0, 10000), 2),
    Qty      = sample(1L:100L, n, replace = TRUE),
    stringsAsFactors = FALSE
  )
  qvdr:::write_test_qvd(df, path, table_name = "LargeTest")
  list(path = path, data = df)
}

#' Create a single-column QVD
#' @keywords internal
make_single_col_qvd <- function(path = tempfile(fileext = ".qvd")) {
  df <- data.frame(OnlyCol = c("x", "y", "z"), stringsAsFactors = FALSE)
  qvdr:::write_test_qvd(df, path, table_name = "SingleCol")
  list(path = path, data = df)
}

#' Create a QVD with a single record
#' @keywords internal
make_single_row_qvd <- function(path = tempfile(fileext = ".qvd")) {
  df <- data.frame(A = 42L, B = "hello", stringsAsFactors = FALSE)
  qvdr:::write_test_qvd(df, path, table_name = "SingleRow")
  list(path = path, data = df)
}
