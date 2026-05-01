# R/read_qvd.R
# ---------------------------------------------------------------------------
# Primary user-facing API for reading QVD files
# ---------------------------------------------------------------------------

#' Read a QVD file into a tibble
#'
#' Reads a QVD (QlikView Data) binary file and returns its contents as a
#' tibble. Column types are inferred from QVD metadata: integers, doubles,
#' dates, timestamps, and strings are all supported.
#'
#' @param path         Path to the `.qvd` file.
#' @param col_select   Optional character vector of column names to load.
#'                     If `NULL` (default), all columns are returned.
#' @param n_max        Optional integer; maximum number of rows to return.
#'                     If `NULL` (default), all rows are returned.
#' @param numeric_as_num Logical (default `TRUE`). If `TRUE`, purely numeric
#'                     symbol tables are returned as double or integer vectors.
#'                     If `FALSE`, all columns are returned as character.
#' @param int_as_int   Logical (default `TRUE`). If `TRUE`, integer symbol
#'                     tables are returned as integer vectors rather than double.
#' @param verbose      Logical (default `TRUE`). If `TRUE`, show progress
#'                     messages and a progress bar for large files.
#'
#' @return A [`tibble::tibble`] with one column per field and one row per
#'   record. Column types:
#'   - `integer` for fields tagged as integers
#'   - `double` for fields tagged as real numbers
#'   - `Date` for fields tagged `$date`
#'   - `POSIXct` for fields tagged `$timestamp`
#'   - `character` for string fields and mixed types
#'
#' @export
#' @examples
#' \dontrun{
#' # Read all columns
#' df <- read_qvd("Sales.qvd")
#'
#' # Read only specific columns
#' df <- read_qvd("Sales.qvd", col_select = c("SalesDate", "Amount", "Region"))
#'
#' # Peek at first 1000 rows
#' df <- read_qvd("Sales.qvd", n_max = 1000)
#'
#' # Return everything as character (no type coercion)
#' df <- read_qvd("Sales.qvd", numeric_as_num = FALSE)
#' }
read_qvd <- function(path,
                     col_select    = NULL,
                     n_max         = NULL,
                     numeric_as_num = TRUE,
                     int_as_int    = TRUE,
                     verbose       = TRUE) {

  path <- validate_qvd_path(path)

  con <- file(path, "rb")
  on.exit(try(close(con), silent = TRUE), add = TRUE)

  if (verbose) {
    cli::cli_alert_info("Reading {.file {basename(path)}}")
  }

  # 1. Parse XML header -------------------------------------------------------
  header <- parse_qvd_header(con)

  if (verbose) {
    n_fields <- length(header$fields)
    cli::cli_alert_info(
      "  {header$n_records} record{?s}, {n_fields} field{?s}"
    )
  }

  if (header$n_records == 0L) {
    cli::cli_alert_warning("QVD file contains no records.")
    empty <- lapply(header$fields, function(f) character(0))
    names(empty) <- sapply(header$fields, `[[`, "name")
    return(tibble::as_tibble(empty))
  }

  # 2. Parse symbol table -----------------------------------------------------
  symbol_table <- parse_qvd_symbols(
    con            = con,
    fields         = header$fields,
    symbol_byte_size = header$symbol_byte_size,
    numeric_as_num = numeric_as_num,
    int_as_int     = int_as_int
  )

  # 3. Parse data section -----------------------------------------------------
  df <- parse_qvd_data(
    con          = con,
    header       = header,
    symbol_table = symbol_table,
    col_select   = col_select,
    numeric_as_num = numeric_as_num,
    verbose      = verbose
  )

  # 4. Apply n_max row limit --------------------------------------------------
  if (!is.null(n_max)) {
    n_max <- as.integer(n_max)
    if (nrow(df) > n_max) {
      df <- df[seq_len(n_max), , drop = FALSE]
    }
  }

  if (verbose) {
    cli::cli_alert_success(
      "Done. {nrow(df)} x {ncol(df)} tibble."
    )
  }

  df
}


#' Read QVD file metadata only (fast, no data loaded)
#'
#' Reads and parses only the XML header of a QVD file. This is very fast
#' even for large files since it reads only a few kilobytes.
#'
#' @param path Path to the `.qvd` file.
#' @return A list with:
#'   - `table_name`: character, the QVD table name
#'   - `created_date`: character, when the file was created
#'   - `n_records`: integer, number of records
#'   - `n_fields`: integer, number of fields
#'   - `fields`: a data frame with one row per field and columns
#'     `name`, `type`, `tags`, `num_symbols`, `bit_width`
#'   - `raw_xml`: character, the raw XML header string
#'
#' @export
#' @examples
#' \dontrun{
#' meta <- qvd_metadata("Sales.qvd")
#' cat("Records:", meta$n_records, "\n")
#' print(meta$fields)
#' }
qvd_metadata <- function(path) {
  path <- validate_qvd_path(path)

  con <- file(path, "rb")
  on.exit(try(close(con), silent = TRUE), add = TRUE)

  header <- parse_qvd_header(con)

  fields_df <- data.frame(
    name        = sapply(header$fields, `[[`, "name"),
    type        = sapply(header$fields, function(f) f$type %||% NA_character_),
    tags        = sapply(header$fields, function(f) paste(f$tags, collapse = ", ")),
    num_symbols = sapply(header$fields, `[[`, "num_symbols"),
    bit_width   = sapply(header$fields, `[[`, "bit_width"),
    stringsAsFactors = FALSE
  )

  list(
    table_name   = header$table_name,
    created_date = header$created_date,
    n_records    = header$n_records,
    n_fields     = length(header$fields),
    fields       = fields_df,
    raw_xml      = header$raw_xml
  )
}


#' List field names in a QVD file
#'
#' A lightweight convenience function that returns only the field names
#' from a QVD file's header, without loading any data.
#'
#' @param path Path to the `.qvd` file.
#' @return A character vector of field names, in the order they appear
#'   in the QVD file.
#'
#' @export
#' @examples
#' \dontrun{
#' qvd_fields("Sales.qvd")
#' #> [1] "SalesDate" "ProductID" "Region" "Amount"
#' }
qvd_fields <- function(path) {
  meta <- qvd_metadata(path)
  meta$fields$name
}


#' Get the full schema of a QVD file as a tibble
#'
#' Returns detailed schema information for each field, including inferred
#' R type, QVD type, Qlik tags, number of distinct values, and bit width.
#'
#' @param path Path to the `.qvd` file.
#' @return A tibble with one row per field and columns:
#'   `name`, `r_type`, `qvd_type`, `tags`, `n_distinct`, `bit_width`.
#'
#' @export
#' @examples
#' \dontrun{
#' schema <- qvd_schema("Sales.qvd")
#' print(schema)
#' }
qvd_schema <- function(path) {
  path <- validate_qvd_path(path)

  con <- file(path, "rb")
  on.exit(try(close(con), silent = TRUE), add = TRUE)

  header       <- parse_qvd_header(con)
  symbol_table <- parse_qvd_symbols(
    con              = con,
    fields           = header$fields,
    symbol_byte_size = header$symbol_byte_size
  )

  rows <- lapply(seq_along(header$fields), function(i) {
    f    <- header$fields[[i]]
    syms <- symbol_table[[f$name]]
    list(
      name       = f$name,
      r_type     = class(syms)[1],
      qvd_type   = f$type %||% NA_character_,
      tags       = paste(f$tags, collapse = ", "),
      n_distinct = length(syms),
      bit_width  = f$bit_width
    )
  })

  tibble::as_tibble(do.call(rbind, lapply(rows, as.data.frame,
                                          stringsAsFactors = FALSE)))
}
