# tests/testthat/test-read_qvd.R
# ---------------------------------------------------------------------------
# Tests for the main read_qvd() function
# ---------------------------------------------------------------------------

test_that("read_qvd returns a tibble", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  result <- read_qvd(fix$path, verbose = FALSE)
  expect_s3_class(result, "tbl_df")
})

test_that("read_qvd returns correct dimensions", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  result <- read_qvd(fix$path, verbose = FALSE)
  expect_equal(nrow(result), nrow(fix$data))
  expect_equal(ncol(result), ncol(fix$data))
})

test_that("read_qvd returns correct column names", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  result <- read_qvd(fix$path, verbose = FALSE)
  expect_equal(names(result), names(fix$data))
})

test_that("read_qvd returns correct string values", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  result <- read_qvd(fix$path, verbose = FALSE)
  expect_equal(as.character(result$Name), fix$data$Name)
})

test_that("read_qvd returns correct integer values", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  result <- read_qvd(fix$path, verbose = FALSE)
  expect_equal(as.integer(result$ID), fix$data$ID)
  expect_equal(as.integer(result$Score), fix$data$Score)
})

test_that("read_qvd handles double columns", {
  fix <- make_numeric_qvd()
  on.exit(unlink(fix$path))
  result <- read_qvd(fix$path, verbose = FALSE)
  expect_equal(as.double(result$Amount), fix$data$Amount, tolerance = 1e-6)
  expect_equal(as.double(result$Tax),    fix$data$Tax,    tolerance = 1e-6)
})

test_that("read_qvd handles NA values correctly", {
  fix <- make_na_qvd()
  on.exit(unlink(fix$path))
  result <- read_qvd(fix$path, verbose = FALSE)
  expect_true(is.na(result$Label[2]))
  expect_true(is.na(result$Label[4]))
  expect_true(is.na(result$Value[2]))
  expect_true(is.na(result$Value[4]))
  expect_false(is.na(result$Label[1]))
  expect_false(is.na(result$Value[3]))
})

test_that("read_qvd col_select returns subset of columns", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  result <- read_qvd(fix$path, col_select = c("ID", "Name"), verbose = FALSE)
  expect_equal(names(result), c("ID", "Name"))
  expect_equal(nrow(result), nrow(fix$data))
})

test_that("read_qvd col_select with single column", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  result <- read_qvd(fix$path, col_select = "Score", verbose = FALSE)
  expect_equal(names(result), "Score")
})

test_that("read_qvd col_select errors on non-existent column", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  expect_error(
    read_qvd(fix$path, col_select = "NoSuchColumn", verbose = FALSE),
    regexp = "NoSuchColumn"
  )
})

test_that("read_qvd n_max limits rows returned", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  result <- read_qvd(fix$path, n_max = 3L, verbose = FALSE)
  expect_equal(nrow(result), 3L)
})

test_that("read_qvd n_max larger than file returns all rows", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  result <- read_qvd(fix$path, n_max = 999L, verbose = FALSE)
  expect_equal(nrow(result), nrow(fix$data))
})

test_that("read_qvd handles single-column QVD", {
  fix <- make_single_col_qvd()
  on.exit(unlink(fix$path))
  result <- read_qvd(fix$path, verbose = FALSE)
  expect_equal(ncol(result), 1L)
  expect_equal(as.character(result[[1]]), fix$data$OnlyCol)
})

test_that("read_qvd handles single-row QVD", {
  fix <- make_single_row_qvd()
  on.exit(unlink(fix$path))
  result <- read_qvd(fix$path, verbose = FALSE)
  expect_equal(nrow(result), 1L)
  expect_equal(as.integer(result$A), 42L)
  expect_equal(as.character(result$B), "hello")
})

test_that("read_qvd errors on non-existent file", {
  expect_error(
    read_qvd("/no/such/file.qvd"),
    regexp = "not found"
  )
})

test_that("read_qvd errors on non-character path", {
  expect_error(read_qvd(123), regexp = "character")
})

test_that("read_qvd verbose = FALSE suppresses messages", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  expect_no_message(read_qvd(fix$path, verbose = FALSE))
})

test_that("read_qvd with numeric_as_num = FALSE returns all character", {
  fix <- make_numeric_qvd()
  on.exit(unlink(fix$path))
  result <- read_qvd(fix$path, numeric_as_num = FALSE, verbose = FALSE)
  # All columns should be character
  types <- sapply(result, class)
  expect_true(all(types == "character"))
})

test_that("read_qvd row values are in correct order", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  result <- read_qvd(fix$path, verbose = FALSE)
  # Row 1: ID=1, Name="Alice", Score=88
  expect_equal(as.integer(result$ID[1]),    1L)
  expect_equal(as.character(result$Name[1]), "Alice")
  expect_equal(as.integer(result$Score[1]), 88L)
  # Row 3: ID=3, Name="Charlie", Score=95
  expect_equal(as.integer(result$ID[3]),    3L)
  expect_equal(as.character(result$Name[3]), "Charlie")
  expect_equal(as.integer(result$Score[3]), 95L)
})
