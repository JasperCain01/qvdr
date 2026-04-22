# R/qvdr-package.R
# ---------------------------------------------------------------------------
# Package-level documentation and hooks
# ---------------------------------------------------------------------------

#' qvdr: Read QVD Files from QlikView and Qlik Sense
#'
#' @description
#' The qvdr package reads QVD (QlikView Data) binary files — Qlik's proprietary
#' high-performance columnar format — into R tibbles.
#'
#' ## Key functions
#'
#' - [read_qvd()]: Read a QVD file into a tibble (main entry point)
#' - [qvd_metadata()]: Read only the header metadata (fast)
#' - [qvd_fields()]: List field names in a QVD file
#' - [qvd_schema()]: Get detailed schema including R types and distinct counts
#'
#' ## QVD format notes
#'
#' A QVD file has three sections:
#' 1. **XML header**: metadata including field names, types, Qlik tags, and
#'    layout parameters for the bit-packed data section.
#' 2. **Symbol table**: per-field dictionaries of all unique values, encoded
#'    as typed entries (int32, double, or null-terminated string).
#' 3. **Data section**: a bit-packed record matrix where each row's fields are
#'    encoded as variable-width indices into the symbol table.
#'
#' The bit-extraction inner loop is implemented in C++ via [Rcpp] for
#' performance. Reading a 1 million-row, 20-column QVD file typically
#' completes in 1–3 seconds on a modern machine.
#'
#' ## Type mapping
#'
#' | QVD / Qlik tag | R type       |
#' |----------------|--------------|
#' | INTEGER        | `integer`    |
#' | REAL / FIX     | `double`     |
#' | `$date`        | `Date`       |
#' | `$timestamp`   | `POSIXct`    |
#' | ASCII (string) | `character`  |
#'
#' @keywords internal
"_PACKAGE"

#' @useDynLib qvdr, .registration = TRUE
#' @importFrom Rcpp sourceCpp evalCpp
NULL

# NOTE FOR DEVELOPERS:
# If you see "could not find function 'parse_symbol_section_cpp'" or similar,
# you must run:
#
#   Rcpp::compileAttributes()   # generates R/RcppExports.R + src/RcppExports.cpp
#   devtools::document()        # regenerates NAMESPACE
#   devtools::load_all()        # reloads the package with compiled C++
#
# This is required any time you add, remove, or rename a [[Rcpp::export]] function.
# The file R/RcppExports.R must exist — it is NOT committed to git by some
# workflows, so new contributors must regenerate it locally.

# Suppress R CMD CHECK notes for internal C++ symbols
utils::globalVariables(c(
  "extract_bits_cpp",
  "parse_symbol_section_cpp",
  "parse_strings_cpp",
  "read_int32_le",
  "read_double_le"
))
