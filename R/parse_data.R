# R/parse_data.R
# ---------------------------------------------------------------------------
# QVD data section (bit-stuffed record matrix) parsing
#
# The data section follows the symbol section. Each record is `record_byte_size`
# bytes. Within each record, each field occupies `bit_width` bits at `bit_offset`
# bits from the start of the record (little-endian bit ordering).
#
# The C++ function `extract_bits_cpp` does the heavy lifting. This file
# handles reading the raw data and mapping indices back to symbol values.
# ---------------------------------------------------------------------------

#' Parse the QVD data section into a data frame
#'
#' Decodes the bit-packed record matrix by extracting field indices for each record,
#' mapping them to their symbol values, and applying type coercion based on field metadata.
#'
#' @param con          Open binary connection at the start of the data section.
#' @param header       Parsed header from `parse_qvd_header()`.
#' @param symbol_table Named list of symbol vectors from `parse_qvd_symbols()`.
#' @param col_select   Character vector of column names to return, or NULL for all.
#' @param numeric_as_num Logical (default TRUE); if FALSE, don't coerce character strings to numeric.
#'                      This parameter is passed to coerce_column to honor the promise that
#'                      numeric_as_num=FALSE returns all columns as character.
#' @param verbose      Logical; print progress bar.
#' @return A tibble.
#' @keywords internal
parse_qvd_data <- function(con, header, symbol_table,
                            col_select = NULL,
                            numeric_as_num = TRUE,
                            verbose    = TRUE) {

  n_records        <- header$n_records
  record_byte_size <- header$record_byte_size
  fields           <- header$fields

  # Filter fields early if col_select is specified
  if (!is.null(col_select)) {
    field_names <- vapply(fields, `[[`, character(1L), "name")
    keep        <- field_names %in% col_select
    if (!any(keep)) {
      cli::cli_abort(
        "None of the requested columns {.val {col_select}} exist in the QVD file."
      )
    }
    fields       <- fields[keep]
    symbol_table <- symbol_table[vapply(fields, `[[`, character(1L), "name")]
  }

  if (n_records == 0L) {
    empty <- lapply(fields, function(f) character(0))
    names(empty) <- vapply(fields, `[[`, character(1L), "name")
    return(tibble::as_tibble(empty))
  }

  # Read entire data section at once
  total_data_bytes <- n_records * record_byte_size
  raw_data <- readBin(con, raw(), n = total_data_bytes)

  if (length(raw_data) < total_data_bytes) {
    cli::cli_warn(
      "Data section shorter than expected ({length(raw_data)} vs \\
       {total_data_bytes} bytes)."
    )
    n_records <- length(raw_data) %/% record_byte_size
  }

  # Extract each field's indices via C++, then map to symbol values
  n_fields <- length(fields)
  result   <- vector("list", n_fields)
  names(result) <- vapply(fields, `[[`, character(1L), "name")

  if (verbose && n_fields > 3L) {
    pb <- cli::cli_progress_bar("Decoding fields", total = n_fields)
  } else {
    pb <- NULL
  }

  for (i in seq_along(fields)) {
    f    <- fields[[i]]
    syms <- symbol_table[[f$name]]

    # C++ bit extraction -> 1-based integer indices (NA where null)
    indices <- extract_bits_cpp(
      raw_data         = raw_data,
      n_records        = n_records,
      record_byte_size = record_byte_size,
      bit_offset       = f$bit_offset,
      bit_width        = f$bit_width,
      bias             = f$bias
    )

    # Map indices to symbol values
    result[[i]] <- map_indices_to_symbols(indices, syms, f, numeric_as_num)

    if (!is.null(pb)) cli::cli_progress_update(id = pb)
  }

  if (!is.null(pb)) cli::cli_progress_done(id = pb)

  tibble::as_tibble(result)
}


#' Map integer indices to symbol values with type coercion
#'
#' Converts the bit-extracted 1-based indices into actual symbol values by indexing into
#' the symbol vector, then applies type coercion (e.g., string to Date, string to numeric).
#'
#' @param indices Integer vector of 1-based symbol indices (NA = null/missing values).
#' @param syms    Symbol vector for this field (already typed by parse_qvd_symbols).
#' @param field   Field metadata list (from parse_qvd_header).
#' @param numeric_as_num Logical (default TRUE); if FALSE, don't coerce character strings to numeric.
#'                      This parameter must be passed through to coerce_column to prevent
#'                      unwanted auto-conversion (e.g., "£1.00" → 1.00) when the user
#'                      explicitly requested all columns as character.
#' @return A typed R vector (integer, double, Date, POSIXct, or character).
#' @keywords internal
map_indices_to_symbols <- function(indices, syms, field, numeric_as_num = TRUE) {
  if (length(syms) == 0L) {
    return(rep(NA_character_, length(indices)))
  }

  # Clamp out-of-range indices to NA
  bad <- !is.na(indices) & (indices < 1L | indices > length(syms))
  if (any(bad)) {
    indices[bad] <- NA_integer_
  }

  # Index into symbol vector (NA propagates automatically)
  raw_vec <- syms[indices]

  # Apply type coercion based on the symbol vector type
  coerce_column(raw_vec, field, numeric_as_num)
}


#' Coerce a symbol vector to its appropriate R type
#'
#' Applies semantic type conversions based on QVD field metadata:
#' - Numeric fields with $date tag → Date class (stores days since 1899-12-30)
#' - Numeric fields with $timestamp tag → POSIXct class (stores days + fraction)
#' - Character fields that parse as dates → Date class
#' - Character numeric fields (when numeric_as_num=TRUE) → numeric class
#'
#' The numeric_as_num parameter is critical: it controls whether character strings
#' representing numbers should be converted to numeric types. When FALSE, this function
#' respects the user's request to keep all columns as character (per read_qvd docstring).
#'
#' @param vec   Vector of raw symbol values (integer, double, or character).
#' @param field Field metadata list from parse_qvd_header.
#' @param numeric_as_num Logical (default TRUE). If TRUE, character strings representing
#'                      numbers are converted to numeric. If FALSE, they are kept as strings.
#'                      Example: numeric_as_num=FALSE keeps "100.5" as character instead of 100.5.
#' @return A typed R vector (integer, double, Date, POSIXct, or character).
#' @keywords internal
coerce_column <- function(vec, field, numeric_as_num = TRUE) {
  tags   <- field$tags   %||% character(0)
  qtype  <- field$type   %||% ""
  nfmt   <- field$number_format %||% ""

  # Already typed from symbol parsing (int/double case)
  if (is.integer(vec) || is.double(vec)) {
    # Date: Qlik stores dates as days since 1899-12-30 (Excel epoch, a historical spreadsheet convention)
    if ("$date" %in% tags || isTRUE(nfmt == "DATE")) {
      return(as.Date(vec, origin = "1899-12-30"))
    }
    # Timestamp: days + fraction of day since 1899-12-30
    # Multiply by 86400 to convert decimal days to seconds from Unix epoch
    if ("$timestamp" %in% tags || isTRUE(nfmt == "TIMESTAMP")) {
      secs <- as.double(vec) * 86400
      return(as.POSIXct(secs, origin = "1899-12-30", tz = "UTC"))
    }
    # Time: fraction of day (e.g., 0.5 = noon, 1.0 = end of day)
    if ("$time" %in% tags || isTRUE(nfmt == "TIME")) {
      return(as.double(vec) * 86400)  # convert to seconds since midnight
    }
    return(vec)
  }

  # Character vector: attempt smart coercion
  if (is.character(vec)) {
    # Explicit date from tags: try parsing with common date formats
    if ("$date" %in% tags) {
      parsed <- as.Date(vec, tryFormats = c("%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y"))
      if (mean(is.na(parsed)) <= 0.1) return(parsed)  # allow 10% parse failures
    }

    # Try numeric coercion for numeric QVD types stored as string.
    # CRITICAL: This only happens if numeric_as_num=TRUE, respecting the user's explicit request.
    # When numeric_as_num=FALSE, all columns stay as character per the read_qvd() docstring promise.
    if (numeric_as_num && qtype %in% c("INTEGER", "REAL", "FIX", "MONEY")) {
      num <- as.numeric(vec)
      if (sum(is.na(num)) == sum(is.na(vec))) return(num)
    }

    return(vec)
  }

  vec
}
