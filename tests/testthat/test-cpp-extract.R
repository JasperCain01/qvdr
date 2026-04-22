# tests/testthat/test-cpp-extract.R
# ---------------------------------------------------------------------------
# Unit tests for the C++ bit extraction functions
# ---------------------------------------------------------------------------

test_that("extract_bits_cpp handles bit_width = 0 (single-symbol field)", {
  # When bit_width = 0, all records reference the same (only) symbol
  raw_data <- raw(10)  # 10 zero bytes = 1 record of 10 bytes
  result <- extract_bits_cpp(
    raw_data         = raw_data,
    n_records        = 1L,
    record_byte_size = 10L,
    bit_offset       = 0L,
    bit_width        = 0L,
    bias             = 0L   # bias=0 means index=0+0+1=1
  )
  expect_equal(result, 1L)
})

test_that("extract_bits_cpp returns NA for null sentinel (bias = -1)", {
  # With bias=-1, a stored value of 0 => sym_idx = 0 + (-1) + 1 = 0 => NA
  raw_data <- as.raw(c(0x00, 0x00))  # all zero bits => stored index = 0
  result <- extract_bits_cpp(
    raw_data         = raw_data,
    n_records        = 1L,
    record_byte_size = 2L,
    bit_offset       = 0L,
    bit_width        = 3L,
    bias             = -1L
  )
  expect_true(is.na(result[1]))
})

test_that("extract_bits_cpp extracts 1-bit fields correctly", {
  # Two records, 1 byte each, 1-bit field at offset 0
  # Record 1: 0x01 (bit 0 = 1)  => stored index 1 => sym_idx = 1 + (-1) + 1 = 1
  # Record 2: 0x00 (bit 0 = 0)  => stored index 0 => sym_idx = 0 => NA
  raw_data <- as.raw(c(0x01, 0x00))
  result <- extract_bits_cpp(
    raw_data         = raw_data,
    n_records        = 2L,
    record_byte_size = 1L,
    bit_offset       = 0L,
    bit_width        = 1L,
    bias             = -1L
  )
  expect_equal(result[1], 1L)
  expect_true(is.na(result[2]))
})

test_that("extract_bits_cpp extracts 8-bit field spanning full byte", {
  # 1 record, 1 byte, 8-bit field. Stored value = 0xFF = 255.
  # sym_idx = 255 + 0 + 1 = 256
  raw_data <- as.raw(0xFF)
  result <- extract_bits_cpp(
    raw_data         = raw_data,
    n_records        = 1L,
    record_byte_size = 1L,
    bit_offset       = 0L,
    bit_width        = 8L,
    bias             = 0L
  )
  expect_equal(result[1], 256L)
})

test_that("extract_bits_cpp extracts field with non-zero bit_offset", {
  # 1 record, 1 byte. Field at bit_offset=4, bit_width=4.
  # Byte = 0xA0 = 1010 0000. Bits [4:7] = 1010 = 10 decimal.
  # sym_idx = 10 + 0 + 1 = 11
  raw_data <- as.raw(0xA0)
  result <- extract_bits_cpp(
    raw_data         = raw_data,
    n_records        = 1L,
    record_byte_size = 1L,
    bit_offset       = 4L,
    bit_width        = 4L,
    bias             = 0L
  )
  expect_equal(result[1], 11L)
})

test_that("extract_bits_cpp handles multi-byte records with two fields", {
  # 2-byte record: field1 = bits [0:3], field2 = bits [4:7]
  # Record: 0x12 0x00 => field1 bits = 0010 = 2, field2 bits = 0001 = 1
  # (little-endian bit order: bit0 is LSB of byte0)
  raw_data <- as.raw(c(0x12, 0x00))
  f1 <- extract_bits_cpp(raw_data, 1L, 2L, 0L, 4L, 0L)
  f2 <- extract_bits_cpp(raw_data, 1L, 2L, 4L, 4L, 0L)
  expect_equal(f1[1], 3L)   # 0x2 = 2, +0+1 = 3
  expect_equal(f2[1], 2L)   # 0x1 = 1, +0+1 = 2
})

test_that("extract_bits_cpp handles multiple records correctly", {
  # 3 records, 1 byte each, 4-bit field at offset 0, bias = -1
  # Bytes: 0x01, 0x02, 0x03
  # Stored: 1, 2, 3 => sym_idx: 1, 2, 3
  raw_data <- as.raw(c(0x01, 0x02, 0x03))
  result <- extract_bits_cpp(
    raw_data         = raw_data,
    n_records        = 3L,
    record_byte_size = 1L,
    bit_offset       = 0L,
    bit_width        = 4L,
    bias             = -1L
  )
  expect_equal(result, c(1L, 2L, 3L))
})

test_that("extract_bits_cpp handles 16-bit wide field", {
  # 1 record, 2 bytes, 16-bit field. Value = 0x0102 = 258.
  # sym_idx = 258 + 0 + 1 = 259
  raw_data <- as.raw(c(0x02, 0x01))  # little-endian: LSB first
  result <- extract_bits_cpp(
    raw_data         = raw_data,
    n_records        = 1L,
    record_byte_size = 2L,
    bit_offset       = 0L,
    bit_width        = 16L,
    bias             = 0L
  )
  expect_equal(result[1], 259L)
})

test_that("parse_strings_cpp parses simple ASCII strings", {
  # "hello\0world\0"
  raw_data <- charToRaw("hello\0world\0")
  result <- parse_strings_cpp(raw_data, c(0L, 6L))
  expect_equal(result[1], "hello")
  expect_equal(result[2], "world")
})

test_that("parse_strings_cpp handles empty string", {
  raw_data <- as.raw(c(0x00))  # single null byte = empty string
  result <- parse_strings_cpp(raw_data, 0L)
  expect_equal(result[1], "")
})

test_that("parse_strings_cpp returns NA for out-of-range offset", {
  raw_data <- charToRaw("abc\0")
  result <- parse_strings_cpp(raw_data, 999L)
  expect_true(is.na(result[1]))
})

test_that("read_int32_le reads correct value", {
  # 0x01000000 in little-endian = 1
  raw_data <- as.raw(c(0x01, 0x00, 0x00, 0x00))
  expect_equal(read_int32_le(raw_data, 0L), 1L)
})

test_that("read_int32_le reads negative integer", {
  # -1 in two's complement little-endian = 0xFFFFFFFF
  raw_data <- as.raw(c(0xFF, 0xFF, 0xFF, 0xFF))
  expect_equal(read_int32_le(raw_data, 0L), -1L)
})

test_that("read_double_le reads IEEE 754 double", {
  # Write 3.14 as little-endian double, read it back
  raw_data <- writeBin(3.14, raw(), size = 8, endian = "little")
  result <- read_double_le(raw_data, 0L)
  expect_equal(result, 3.14, tolerance = 1e-10)
})
