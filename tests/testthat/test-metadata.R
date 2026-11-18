# tests/testthat/test-metadata.R
# ---------------------------------------------------------------------------
# qvd_metadata(), qvd_fields() and qvd_schema(): reading a file's description
# without reading its data. See tests/TESTS.md.
# ---------------------------------------------------------------------------

test_that("qvd_metadata describes the table, its fields and its record count", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  meta <- qvd_metadata(fix$path)

  expect_named(meta, c("table_name", "created_date", "n_records",
                       "n_fields", "fields", "raw_xml"),
               ignore.order = TRUE)
  expect_equal(meta$table_name, "SimpleTest")
  expect_equal(meta$n_records, nrow(fix$data))
  expect_equal(meta$n_fields, ncol(fix$data))
  expect_s3_class(meta$fields, "data.frame")
  expect_true(all(c("name", "type", "num_symbols") %in% names(meta$fields)))
  expect_equal(meta$fields$name, names(fix$data))
  expect_match(meta$raw_xml, "QvdTableHeader")
})

test_that("qvd_fields returns the field names in file order", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  expect_identical(qvd_fields(fix$path), c("ID", "Name", "Score"))
})

test_that("qvd_schema returns one row per field with its distinct-value count", {
  fix <- make_simple_qvd()
  on.exit(unlink(fix$path))
  schema <- qvd_schema(fix$path)
  expect_s3_class(schema, "tbl_df")
  expect_true(all(c("name", "r_type", "qvd_type", "n_distinct", "bit_width")
                  %in% names(schema)))
  expect_equal(schema$name, names(fix$data))
  expect_equal(schema$n_distinct, c(5L, 5L, 5L))

  # n_distinct counts distinct values, not rows.
  path <- tempfile(fileext = ".qvd")
  on.exit(unlink(path), add = TRUE)
  qvdr:::write_test_qvd(
    data.frame(Region = c("A", "B", "A", "C", "B", "A"), stringsAsFactors = FALSE), path)
  expect_equal(qvd_schema(path)$n_distinct, 3L)
})
