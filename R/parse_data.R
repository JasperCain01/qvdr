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
#' @param con          Open binary connection at the start of the data section.
#' @param header       Parsed header from `parse_qvd_header()`.
#' @param symbol_table Named list of symbol vectors from `parse_qvd_symbols()`.
#' @param col_select   Character vector of column names to return, or NULL for all.
#' @param verbose      Logical; print progress bar.
#' @return A tibble.
#' @keywords internal
parse_qvd_data <- function(con, header, symbol_table,
                            col_select = NULL,
                            verbose    = TRUE) {

  n_records        <- header$n_records
  record_byte_size <- header$record_byte_size
  fields           <- header$fields

  # Filter fields early if col_select is specified
  if (!is.null(col_select)) {
    field_names <- sapply(fields, `[[`, "name")
    keep        <- field_names %in% col_select
    if (!any(keep)) {
      cli::cli_abort(
        "None of the requested columns ({paste(col_select, collapse=', ')}) \\
         exist in the QVD file."
      )
    }
    fields       <- fields[keep]
    symbol_table <- symbol_table[sapply(fields, `[[`, "name")]
  }

  if (n_records == 0L) {
    empty <- lapply(fields, function(f) character(0))
    names(empty) <- sapply(fields, `[[`, "name")
    return(tibble::as_tibble(empty))
  }

  # Read entire data section at once
  total_data_bytes <- n_records * record_byte_size
  raw_data <- readBin(con, raw(), n = total_data_bytes)

  if (length(raw_data) < total_data_bytes) {
    cli::cli_alert_warning(
      "Data section shorter than expected ({length(raw_data)} vs \\
       {total_data_bytes} bytes)."
    )
    n_records <- length(raw_data) %/% record_byte_size
  }

  # Extract each field's indices via C++, then map to symbol values
  n_fields <- length(fields)
  result   <- vector("list", n_fields)
  names(result) <- sapply(fields, `[[`, "name")

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
    result[[i]] <- map_indices_to_symbols(indices, syms, f)

    if (!is.null(pb)) cli::cli_progress_update(id = pb)
  }

  if (!is.null(pb)) cli::cli_progress_done(id = pb)

  tibble::as_tibble(result)
}


#' Map integer indices to symbol values with type coercion
#'
#' @param indices Integer vector of 1-based symbol indices (NA = null).
#' @param syms    Symbol vector for this field.
#' @param field   Field metadata list.
#' @return A typed R vector.
#' @keywords internal
map_indices_to_symbols <- function(indices, syms, field) {
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
  coerce_column(raw_vec, field)
}


#' Coerce a raw symbol vector to its appropriate R type
#'
#' Uses QVD field metadata (type, tags, number_format) to produce the most
#' appropriate R type: integer, double, Date, POSIXct, or character.
#'
#' @param vec   Vector of raw symbol values (integer, double, or character).
#' @param field Field metadata list.
#' @return A typed R vector.
#' @keywords internal
coerce_column <- function(vec, field) {
  tags   <- field$tags   %||% character(0)
  qtype  <- field$type   %||% ""
  nfmt   <- field$number_format %||% ""

  # Already typed from symbol parsing
  if (is.integer(vec) || is.double(vec)) {
    # Date: Qlik stores dates as days since 1899-12-30 (Excel epoch)
    if ("$date" %in% tags || nfmt == "D") {
      return(as.Date(vec, origin = "1899-12-30"))
    }
    # Timestamp: days + fraction of day since 1899-12-30
    if ("$timestamp" %in% tags || nfmt == "DT") {
      secs <- as.double(vec) * 86400
      return(as.POSIXct(secs, origin = "1899-12-30", tz = "UTC"))
    }
    # Time: fraction of day
    if ("$time" %in% tags || nfmt == "T") {
      return(as.double(vec) * 86400)  # seconds since midnight
    }
    return(vec)
  }

  # Character vector: attempt smart coercion
  if (is.character(vec)) {
    # Explicit date/time from tags on a string field
    if ("$date" %in% tags) {
      parsed <- as.Date(vec, tryFormats = c("%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y"))
      if (mean(is.na(parsed)) <= 0.1) return(parsed)  # allow 10% parse failures
    }

    # Try numeric coercion for numeric QVD types stored as string
    if (qtype %in% c("INTEGER", "REAL", "FIX", "MONEY")) {
      num <- suppressWarnings(as.numeric(vec))
      if (mean(is.na(num)) <= mean(is.na(vec))) return(num)
    }

    return(vec)
  }

  vec
}
