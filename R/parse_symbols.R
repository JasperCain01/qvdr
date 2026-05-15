# R/parse_symbols.R
# ---------------------------------------------------------------------------
# QVD symbol table parsing
#
# The symbol section immediately follows the header (after the null byte).
# Each field's symbols are stored contiguously in the order fields appear
# in the header. For each symbol, a 1-byte type code precedes the value.
#
# Type codes:
#   0x01 => INT32    (4 bytes, little-endian)
#   0x02 => DOUBLE   (8 bytes, little-endian IEEE 754)
#   0x04 => STRING   (null-terminated UTF-8)
#   0x05 => DUAL_INT (4-byte int + null-terminated string; string is display)
#   0x06 => DUAL_DBL (8-byte double + null-terminated string; string is display)
#
# We read the entire symbol section as a single raw vector and pass it to
# the C++ parser for maximum speed.
# ---------------------------------------------------------------------------

#' Parse the QVD symbol table section
#'
#' Reads the full symbol section from the connection, dispatches to the C++
#' parser, and assembles typed R vectors for each field.
#'
#' @param con         Open binary connection, positioned at start of symbol section.
#' @param fields      Field metadata list from `parse_qvd_header()`.
#' @param symbol_byte_size Total byte length of the symbol section.
#' @param numeric_as_num Logical; if TRUE, numeric symbols return as double vectors.
#' @param int_as_int   Logical; if TRUE, integer symbols return as integer vectors.
#' @return A named list of vectors (one per field), typed appropriately.
#' @keywords internal
parse_qvd_symbols <- function(con, fields, symbol_byte_size,
                               numeric_as_num = TRUE,
                               int_as_int     = TRUE) {

  # Read entire symbol section at once
  raw_sym <- readBin(con, raw(), n = symbol_byte_size)

  if (length(raw_sym) < symbol_byte_size) {
    cli::cli_warn(
      "Symbol section shorter than expected ({length(raw_sym)} vs {symbol_byte_size} bytes). \\
       File may be truncated."
    )
  }

  # Use the C++ parser to walk the raw bytes and extract per-field type info
  num_symbols <- vapply(fields, `[[`, integer(1L), "num_symbols")
  parsed      <- parse_symbol_section_cpp(raw_sym, as.integer(num_symbols))

  # Assemble typed vectors for each field
  result <- vector("list", length(fields))
  names(result) <- vapply(fields, `[[`, character(1L), "name")

  for (i in seq_along(fields)) {
    f    <- fields[[i]]
    p    <- parsed[[i]]

    types      <- p$types
    int_vals   <- p$int_vals
    dbl_vals   <- p$dbl_vals
    str_starts <- p$str_starts

    n <- f$num_symbols

    if (n == 0L) {
      result[[i]] <- character(0)
      next
    }

    # Determine the dominant type for this field based on symbol types present and field metadata
    dominant <- determine_dominant_type(types, f)

    # DUAL symbol types (0x05 = DUAL_INT, 0x06 = DUAL_DBL) store both a numeric value and
    # a display string (e.g., for currency: numeric 1.0 with display "£1.00"). The determine_dominant_type
    # function correctly identifies these as "dual_int" or "dual_dbl", but they need to be routed
    # to their numeric paths here, not the string path. This ensures fields with DUAL symbols return
    # their actual numeric values, not the display strings.
    # Also note: When numeric_as_num = FALSE, we skip the numeric path entirely to preserve
    # the docstring promise that "all columns are returned as character".
    if (dominant %in% c("integer", "dual_int") && int_as_int && numeric_as_num) {
      # Integer or DUAL_INT with numeric interpretation enabled
      result[[i]] <- int_vals

    } else if (dominant %in% c("double", "dual_dbl") && numeric_as_num) {
      # Double or DUAL_DBL: prefer the double value, but fall back to converting int to double
      # if double is missing (can happen with mixed DUAL_INT/DUAL_DBL in the same field).
      # This handles the common case where DUAL_INT fields store integers but we want them as doubles.
      vec <- dbl_vals
      fill <- is.na(dbl_vals) & !is.na(int_vals)
      vec[fill] <- as.double(int_vals[fill])
      result[[i]] <- vec

    } else {
      # String or dual-as-string: extract strings using C++
      has_str <- str_starts >= 0L
      vec      <- character(n)
      vec[!has_str] <- NA_character_

      if (any(has_str)) {
        str_idx          <- which(has_str)
        vec[str_idx] <- parse_strings_cpp(raw_sym, str_starts[str_idx])
      }

      # Fill non-string types with their numeric representation
      is_int_only  <- types == 0x01
      is_dbl_only  <- types == 0x02
      vec[is_int_only] <- as.character(int_vals[is_int_only])
      vec[is_dbl_only] <- as.character(dbl_vals[is_dbl_only])

      result[[i]] <- vec
    }
  }

  result
}


#' Determine the dominant storage type for a field's symbols
#'
#' Uses the QVD field `type` tag and actual symbol types to decide how to
#' expose the field in R.
#'
#' @param types Integer vector of symbol type codes.
#' @param field A single field metadata list.
#' @return One of "integer", "double", "string", "dual_int", "dual_dbl".
#' @keywords internal
determine_dominant_type <- function(types, field) {
  qvd_type <- field$type %||% ""
  tags      <- field$tags

  # Explicit QVD type hints
  if (isTRUE(qvd_type == "INTEGER")) return("integer")
  if (isTRUE(qvd_type %in% c("REAL", "FIX", "MONEY"))) return("double")

  # Check tags
  if (any(c("$date", "$timestamp", "$time") %in% tags)) return("double")

  # Fall back to inspecting actual symbol types used
  unique_types <- unique(types)

  if (all(unique_types == 0x01))            return("integer")
  if (all(unique_types == 0x02))            return("double")
  if (all(unique_types == 0x04))            return("string")
  if (all(unique_types %in% c(0x05, 0x01))) return("dual_int")
  if (all(unique_types %in% c(0x06, 0x02))) return("dual_dbl")

  # Mixed: default to string representation
  "string"
}
