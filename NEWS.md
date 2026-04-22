# qvdr (development version)

# qvdr 0.1.0

## New features

* `read_qvd()`: Read a QVD file into a tibble with full type coercion.
  Supports `col_select` for column subsetting and `n_max` for row limiting.
* `qvd_metadata()`: Read only the XML header — table name, record count,
  field names, types, and tags — without loading any data.
* `qvd_fields()`: Return just the field names from a QVD header.
* `qvd_schema()`: Return a tibble with per-field schema including inferred
  R type, QVD type, Qlik tags, distinct value count, and bit width.
* C++ backend (`Rcpp`) for high-performance bit-packed index extraction.
* Automatic type coercion: `integer`, `double`, `Date` (`$date` tag),
  `POSIXct` (`$timestamp` tag), and `character`.
* Full support for QVD symbol types: `INT32` (0x01), `DOUBLE` (0x02),
  `STRING` (0x04), `DUAL_INT` (0x05), `DUAL_DBL` (0x06).
* Informative error messages via `cli`.
* Progress bar for large files via `cli`.
