# tests/testthat/test-edge-cases.R
# ---------------------------------------------------------------------------
# Edge case and error handling tests
# ---------------------------------------------------------------------------

test_that("QVD with 0 records returns empty tibble with correct columns", {
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path))
  df <- data.frame(A = integer(0), B = character(0), stringsAsFactors = FALSE)
  qvdr:::write_test_qvd(df, path)
  result <- read_qvd(path, verbose = FALSE)
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
  expect_equal(names(result), c("A", "B"))
})

test_that("reading with col_select preserves row order", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  full   <- read_qvd(fix$path, verbose = FALSE)
  subset <- read_qvd(fix$path, col_select = "Name", verbose = FALSE)
  expect_equal(as.character(subset$Name), as.character(full$Name))
})

test_that("n_max = 0 returns zero rows with correct schema", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  result <- read_qvd(fix$path, n_max = 0L, verbose = FALSE)
  expect_equal(nrow(result), 0L)
  expect_equal(names(result), names(fix$data))
})

test_that("n_max = 1 returns exactly one row", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  result <- read_qvd(fix$path, n_max = 1L, verbose = FALSE)
  expect_equal(nrow(result), 1L)
})

test_that("large file round-trip is correct", {
  fix <- make_large_qvd(n = 10000L)
  on.exit(unlink(fix$path))
  result <- read_qvd(fix$path, verbose = FALSE)
  expect_equal(nrow(result), 10000L)
  expect_equal(ncol(result), ncol(fix$data))
  # Spot-check a few values
  expect_equal(as.integer(result$Qty[1]), fix$data$Qty[1])
  expect_equal(as.character(result$Region[1]), fix$data$Region[1])
})

test_that("col_select ignores unknown columns gracefully when some match", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  # Mix of valid and invalid — should return only the valid ones
  result <- read_qvd(fix$path,
                     col_select = c("ID", "NonExistent"),
                     verbose    = FALSE)
  expect_equal(names(result), "ID")
})

test_that("validate_qvd_path normalises path", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  # Should not error on a valid path
  expect_no_error(qvdr:::validate_qvd_path(fix$path))
})

test_that("validate_qvd_path errors on NULL", {
  expect_error(qvdr:::validate_qvd_path(NULL), "character")
})

test_that("validate_qvd_path errors on vector of paths", {
  expect_error(qvdr:::validate_qvd_path(c("a.qvd", "b.qvd")), "character")
})

test_that("format_bytes produces correct output", {
  expect_equal(qvdr:::format_bytes(512L),        "512 B")
  expect_equal(qvdr:::format_bytes(2048L),        "2.0 KB")
  expect_equal(qvdr:::format_bytes(2L * 1024L^2), "2.0 MB")
  expect_equal(qvdr:::format_bytes(3L * 1024L^3), "3.0 GB")
})

test_that("%||% returns left when non-NULL", {
  expect_equal("hello" %||% "fallback", "hello")
  expect_equal(0L     %||% 99L,         0L)
})

test_that("%||% returns right when NULL", {
  expect_equal(NULL %||% "fallback", "fallback")
  expect_equal(NULL %||% 42L,         42L)
})

test_that("reading same file twice gives identical results", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  r1 <- read_qvd(fix$path, verbose = FALSE)
  r2 <- read_qvd(fix$path, verbose = FALSE)
  expect_equal(r1, r2)
})

test_that("qvd_metadata and read_qvd agree on record count", {
  fix <- make_large_qvd(n = 500L)
  on.exit(unlink(fix$path))
  meta   <- qvd_metadata(fix$path)
  result <- read_qvd(fix$path, verbose = FALSE)
  expect_equal(meta$n_records, nrow(result))
})

test_that("qvd_schema and read_qvd agree on column names", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  schema <- qvd_schema(fix$path)
  result <- read_qvd(fix$path, verbose = FALSE)
  expect_equal(schema$name, names(result))
})

test_that("file with non-.qvd extension raises a warning not an error", {
  path <- tempfile(fileext = ".bin")
  on.exit(unlink(path))
  fix_path <- tempfile(fileext = ".qvd")
  on.exit(unlink(fix_path), add = TRUE)
  df <- data.frame(X = 1L:3L)
  qvdr:::write_test_qvd(df, fix_path)
  file.copy(fix_path, path)
  expect_warning(qvd_metadata(path), regexp = ".qvd")
})

test_that("QVD with 256+ distinct values per field works (requires >8 bit index)", {
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path))
  n <- 300L
  df <- data.frame(
    X = seq_len(n),   # 300 distinct integer values — needs 9-bit index
    stringsAsFactors = FALSE
  )
  qvdr:::write_test_qvd(df, path)
  result <- read_qvd(path, verbose = FALSE)
  expect_equal(nrow(result), n)
  expect_equal(sort(as.integer(result$X)), seq_len(n))
})
