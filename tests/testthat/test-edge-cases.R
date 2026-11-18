# tests/testthat/test-edge-cases.R
# ---------------------------------------------------------------------------
# Degenerate table shapes, bad input, and damaged files. See tests/TESTS.md.
# ---------------------------------------------------------------------------

test_that("degenerate shapes read correctly: no records, one row, one column", {
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path))
  qvdr:::write_test_qvd(data.frame(A = integer(0), B = character(0),
                                   stringsAsFactors = FALSE), path)
  empty <- read_qvd(path, verbose = FALSE)
  expect_s3_class(empty, "tbl_df")
  expect_equal(nrow(empty), 0L)
  expect_equal(names(empty), c("A", "B"))

  fix <- make_single_row_qvd()
  on.exit(unlink(fix$path), add = TRUE)
  expect_identical(read_qvd(fix$path, verbose = FALSE), tibble::as_tibble(fix$data))

  fix <- make_single_col_qvd()
  on.exit(unlink(fix$path), add = TRUE)
  expect_identical(read_qvd(fix$path, verbose = FALSE), tibble::as_tibble(fix$data))
})

test_that("a missing file is reported as not found by every reader", {
  missing <- "/no/such/file.qvd"
  expect_error(read_qvd(missing), "not found")
  expect_error(qvd_metadata(missing), "not found")
  expect_error(qvd_fields(missing), "not found")
  expect_error(qvd_schema(missing), "not found")
})

test_that("a path that is not a single string is rejected with a clear message", {
  expect_error(read_qvd(123), "character")
  expect_error(qvdr:::validate_qvd_path(NULL), "character")
  expect_error(qvdr:::validate_qvd_path(c("a.qvd", "b.qvd")), "character")
})

test_that("a QVD with a non-.qvd extension is read, with a warning", {
  fix_path <- tempfile(fileext = ".qvd")
  path <- tempfile(fileext = ".bin")
  on.exit(unlink(c(fix_path, path)))
  qvdr:::write_test_qvd(data.frame(X = 1L:3L), fix_path)
  file.copy(fix_path, path)
  expect_warning(qvd_metadata(path), regexp = ".qvd")
})

test_that("a truncated or corrupt file never returns data without saying so", {
  # Cuts a real Qlik file short at three points. Today's contract: a damaged
  # header or symbol table is an error; a short data section warns and returns
  # only the records that were complete. What must never happen is a quiet
  # return of partial or garbled data.
  src <- testthat::test_path("testdata", "qcv_test_csv.qvd")
  bytes <- readBin(src, raw(), file.size(src))
  header_end <- which(bytes == as.raw(0))[1]
  cut_to <- function(k) {
    f <- tempfile(fileext = ".qvd")
    writeBin(bytes[seq_len(k)], f)
    f
  }

  expect_error(read_qvd(cut_to(500), verbose = FALSE), "header terminator")
  expect_error(suppressWarnings(read_qvd(cut_to(header_end + 20), verbose = FALSE)))

  expect_warning(
    partial <- read_qvd(cut_to(length(bytes) - 1), verbose = FALSE),
    "shorter than expected"
  )
  expect_identical(partial, read_qvd(src, verbose = FALSE)[1:9, ])

  # Bytes that are not a QVD at all, but do contain a header terminator.
  junk <- tempfile(fileext = ".qvd")
  on.exit(unlink(junk))
  writeBin(as.raw(c(rep(0x41, 100), 0x00, rep(0x42, 100))), junk)
  expect_error(read_qvd(junk, verbose = FALSE), "QVD XML header")
})

test_that("files read correctly under a non-UTF-8 locale", {
  # QVD headers and text values are UTF-8. Decoding them as the session's
  # native encoding broke reading under a non-UTF-8 locale (LANG unset on a
  # Linux server, or Windows with R < 4.2): the real file's "£" number format
  # made the header unparseable, and non-ASCII text values came back unmarked,
  # so anything converting them to UTF-8 produced mojibake.
  vals <- c("caf\u00e9", "\u00a3100", "na\u00efve", "plain")  # built while still UTF-8
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path))
  qvdr:::write_test_qvd(data.frame(X = vals, stringsAsFactors = FALSE), path)

  old <- Sys.getlocale("LC_CTYPE")
  on.exit(Sys.setlocale("LC_CTYPE", old), add = TRUE)
  suppressWarnings(Sys.setlocale("LC_CTYPE", "C"))
  skip_if(l10n_info()[["UTF-8"]], "could not switch to a non-UTF-8 locale")

  result <- read_qvd(path, verbose = FALSE)$X
  expect_identical(result, vals)
  expect_identical(Encoding(result[1:3]), rep("UTF-8", 3))
  expect_identical(enc2utf8(result), vals)

  real <- read_qvd(testthat::test_path("testdata", "qcv_test_csv.qvd"), verbose = FALSE)
  expect_equal(nrow(real), 10L)
  expect_identical(Encoding(qvd_metadata(
    testthat::test_path("testdata", "qcv_test_csv.qvd"))$raw_xml), "UTF-8")
})

test_that("format_bytes reports file sizes in the unit a person would use", {
  expect_equal(qvdr:::format_bytes(512L),        "512 B")
  expect_equal(qvdr:::format_bytes(2048L),       "2.0 KB")
  expect_equal(qvdr:::format_bytes(2L * 1024L^2), "2.0 MB")
  expect_equal(qvdr:::format_bytes(3L * 1024L^3), "3.0 GB")
})
