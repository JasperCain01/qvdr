# tests/testthat/test-read_qvd.R
# ---------------------------------------------------------------------------
# read_qvd(): values, row order, column selection and row limits.
# Fixtures are written by qvdr:::write_test_qvd(), so these tests prove the
# reader and the package's own writer agree. Agreement with real Qlik output
# is tested separately in test-real-qvd.R. See tests/TESTS.md.
# ---------------------------------------------------------------------------

test_that("read_qvd returns the written table exactly: names, types, values and row order", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  expect_identical(read_qvd(fix$path, verbose = FALSE), tibble::as_tibble(fix$data))

  fix <- make_numeric_qvd()
  on.exit(unlink(fix$path), add = TRUE)
  expect_identical(read_qvd(fix$path, verbose = FALSE), tibble::as_tibble(fix$data))
})

test_that("NULL values come back as NA in the right cells, for strings and integers", {
  fix <- make_na_qvd()
  on.exit(unlink(fix$path))
  result <- read_qvd(fix$path, verbose = FALSE)
  expect_identical(result$Label, c("A", NA, "C", NA, "E"))
  expect_identical(result$Value, c(10L, NA, 30L, NA, 50L))

  # A column that is entirely NULL still has the right length and type.
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path), add = TRUE)
  qvdr:::write_test_qvd(data.frame(X = rep(NA_character_, 3), stringsAsFactors = FALSE), path)
  expect_identical(read_qvd(path, verbose = FALSE)$X, rep(NA_character_, 3))
})

test_that("a large multi-column file round-trips exactly, including fields needing a >8-bit index", {
  # 5,000 distinct IDs need a 13-bit symbol index, and the five fields share
  # each record's bytes, so this exercises bit-unpacking across field and byte
  # boundaries. Comparing without sorting catches rows decoded out of order.
  fix <- make_large_qvd(n = 5000L)
  on.exit(unlink(fix$path))
  expect_identical(read_qvd(fix$path, verbose = FALSE), tibble::as_tibble(fix$data))
})

test_that("a field with a single distinct value (a zero-width index) is read for every row", {
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path))
  qvdr:::write_test_qvd(data.frame(X = rep("constant", 10L), stringsAsFactors = FALSE), path)
  expect_identical(read_qvd(path, verbose = FALSE)$X, rep("constant", 10L))
})

test_that("col_select returns the requested columns in file row order, ignoring unknown names", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  expected <- tibble::as_tibble(fix$data)

  expect_identical(read_qvd(fix$path, col_select = c("ID", "Name"), verbose = FALSE),
                   expected[c("ID", "Name")])
  expect_identical(read_qvd(fix$path, col_select = "Score", verbose = FALSE),
                   expected["Score"])
  # A mix of known and unknown names keeps the known ones.
  expect_identical(read_qvd(fix$path, col_select = c("ID", "NonExistent"), verbose = FALSE),
                   expected["ID"])
})

test_that("col_select errors, naming the column, when nothing requested exists", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  expect_error(
    read_qvd(fix$path, col_select = "NoSuchColumn", verbose = FALSE),
    regexp = "NoSuchColumn"
  )
})

test_that("n_max limits rows to the first n, keeping the schema even at zero", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  expected <- tibble::as_tibble(fix$data)
  for (n in c(0L, 3L)) {
    expect_identical(read_qvd(fix$path, n_max = n, verbose = FALSE), expected[seq_len(n), ],
                     info = paste("n_max =", n))
  }
  # Asking for more rows than exist returns them all.
  expect_identical(read_qvd(fix$path, n_max = 999L, verbose = FALSE), expected)
})

test_that("verbose = FALSE suppresses progress messages", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  expect_no_message(read_qvd(fix$path, verbose = FALSE))
})
