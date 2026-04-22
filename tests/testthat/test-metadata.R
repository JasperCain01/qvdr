# tests/testthat/test-metadata.R
# ---------------------------------------------------------------------------
# Tests for qvd_metadata(), qvd_fields(), qvd_schema()
# ---------------------------------------------------------------------------

test_that("qvd_metadata returns a list", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  meta <- qvd_metadata(fix$path)
  expect_type(meta, "list")
})

test_that("qvd_metadata has expected names", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  meta <- qvd_metadata(fix$path)
  expect_named(meta, c("table_name", "created_date", "n_records",
                        "n_fields", "fields", "raw_xml"),
               ignore.order = TRUE)
})

test_that("qvd_metadata reports correct record count", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  meta <- qvd_metadata(fix$path)
  expect_equal(meta$n_records, nrow(fix$data))
})

test_that("qvd_metadata reports correct field count", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  meta <- qvd_metadata(fix$path)
  expect_equal(meta$n_fields, ncol(fix$data))
})

test_that("qvd_metadata fields data frame has correct columns", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  meta <- qvd_metadata(fix$path)
  expect_s3_class(meta$fields, "data.frame")
  expect_true("name" %in% names(meta$fields))
  expect_true("type" %in% names(meta$fields))
  expect_true("num_symbols" %in% names(meta$fields))
})

test_that("qvd_metadata fields has correct names", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  meta <- qvd_metadata(fix$path)
  expect_equal(meta$fields$name, names(fix$data))
})

test_that("qvd_metadata table_name is set", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  meta <- qvd_metadata(fix$path)
  expect_equal(meta$table_name, "SimpleTest")
})

test_that("qvd_metadata raw_xml is a non-empty string", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  meta <- qvd_metadata(fix$path)
  expect_type(meta$raw_xml, "character")
  expect_gt(nchar(meta$raw_xml), 0L)
  expect_true(grepl("QvdTableHeader", meta$raw_xml))
})

test_that("qvd_fields returns character vector", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  fields <- qvd_fields(fix$path)
  expect_type(fields, "character")
})

test_that("qvd_fields returns correct names", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  fields <- qvd_fields(fix$path)
  expect_equal(fields, names(fix$data))
})

test_that("qvd_fields returns names in correct order", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  fields <- qvd_fields(fix$path)
  expect_equal(fields[1], "ID")
  expect_equal(fields[2], "Name")
  expect_equal(fields[3], "Score")
})

test_that("qvd_schema returns a tibble", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  schema <- qvd_schema(fix$path)
  expect_s3_class(schema, "tbl_df")
})

test_that("qvd_schema has expected columns", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  schema <- qvd_schema(fix$path)
  expect_true(all(c("name", "r_type", "qvd_type", "n_distinct", "bit_width")
                  %in% names(schema)))
})

test_that("qvd_schema n_distinct counts are correct", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  schema <- qvd_schema(fix$path)
  # ID: 5 unique values, Name: 5, Score: 5
  expect_equal(schema$n_distinct[schema$name == "ID"],    5L)
  expect_equal(schema$n_distinct[schema$name == "Name"],  5L)
  expect_equal(schema$n_distinct[schema$name == "Score"], 5L)
})

test_that("qvd_schema n_distinct respects duplicates", {
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path))
  df <- data.frame(
    Region = c("A", "B", "A", "C", "B", "A"),
    stringsAsFactors = FALSE
  )
  qvdr:::write_test_qvd(df, path)
  schema <- qvd_schema(path)
  # Only 3 distinct regions
  expect_equal(schema$n_distinct[schema$name == "Region"], 3L)
})

test_that("qvd_metadata errors on missing file", {
  expect_error(qvd_metadata("/no/such/file.qvd"), "not found")
})

test_that("qvd_fields errors on missing file", {
  expect_error(qvd_fields("/no/such/file.qvd"), "not found")
})

test_that("qvd_schema errors on missing file", {
  expect_error(qvd_schema("/no/such/file.qvd"), "not found")
})
