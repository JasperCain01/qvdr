# R/utils.R
# ---------------------------------------------------------------------------
# Internal utility functions
# ---------------------------------------------------------------------------

#' Validate a QVD file path
#'
#' Checks that the file exists and has a `.qvd` extension.
#'
#' @param path Character scalar.
#' @return The normalised path, invisibly.
#' @keywords internal
validate_qvd_path <- function(path) {
  if (!is.character(path) || length(path) != 1L) {
    cli::cli_abort("{.arg path} must be a single character string.")
  }
  path <- normalizePath(path, mustWork = FALSE)
  if (!file.exists(path)) {
    cli::cli_abort("File not found: {.file {path}}")
  }
  ext <- tolower(tools::file_ext(path))
  if (ext != "qvd") {
    cli::cli_alert_warning(
      "{.file {basename(path)}} does not have a .qvd extension. \\
       Attempting to read anyway."
    )
  }
  path
}


#' Null-coalescing operator
#'
#' Returns `x` if it is not `NULL`, otherwise `y`.
#'
#' @param x,y Any R objects.
#' @return `x` if non-`NULL`, else `y`.
#' @keywords internal
`%||%` <- function(x, y) if (!is.null(x)) x else y


#' Format a byte count for human-readable output
#'
#' @param n Integer byte count.
#' @return Character scalar like "1.2 MB".
#' @keywords internal
format_bytes <- function(n) {
  if (n < 1024)             return(paste(n, "B"))
  if (n < 1024^2)           return(sprintf("%.1f KB", n / 1024))
  if (n < 1024^3)           return(sprintf("%.1f MB", n / 1024^2))
  sprintf("%.1f GB", n / 1024^3)
}


#' Write a synthetic QVD file for testing
#'
#' Creates a minimal but valid QVD binary file from a data frame. This is
#' used internally by the test suite to generate fixture files without
#' requiring a Qlik installation.
#'
#' Supports integer, double, and character columns. Date/POSIXct columns
#' are coerced to double (Qlik serial number).
#'
#' @param df       A data.frame or tibble.
#' @param path     Output path for the `.qvd` file.
#' @param table_name Character; the QVD table name embedded in the header.
#' @return `path`, invisibly.
#' @keywords internal
write_test_qvd <- function(df, path, table_name = "TestTable") {
  n_records <- nrow(df)
  n_fields  <- ncol(df)
  field_names <- names(df)

  # ---- Build symbol tables and determine field types ----
  sym_list   <- vector("list", n_fields)    # list of unique symbol values
  type_codes <- integer(n_fields)           # dominant symbol type code per field
  index_mat  <- matrix(0L, n_records, n_fields)  # 0-based indices

  for (j in seq_len(n_fields)) {
    col <- df[[j]]
    if (is.integer(col)) {
      type_codes[j] <- 0x01L
      syms           <- sort(unique(col[!is.na(col)]))
      sym_list[[j]]  <- syms
      # Map values to 0-based indices; NA -> -1 (will use bias)
      idx <- match(col, syms) - 1L
      idx[is.na(idx)] <- -1L
      index_mat[, j]  <- idx

    } else if (is.numeric(col)) {
      type_codes[j] <- 0x02L
      syms           <- sort(unique(col[!is.finite(col) | !is.na(col)]))
      syms           <- syms[is.finite(syms)]
      sym_list[[j]]  <- syms
      idx            <- match(col, syms) - 1L
      idx[is.na(idx)] <- -1L
      index_mat[, j]  <- idx

    } else {
      type_codes[j] <- 0x04L
      col            <- as.character(col)
      syms           <- sort(unique(col[!is.na(col)]))
      sym_list[[j]]  <- syms
      idx            <- match(col, syms) - 1L
      idx[is.na(idx)] <- -1L
      index_mat[, j]  <- idx
    }
  }

  # ---- Compute bit widths ----
  bit_widths <- sapply(sym_list, function(s) {
    n <- length(s) + 1L  # +1 for null sentinel
    if (n <= 1L) return(0L)
    ceiling(log2(n + 1L))
  })

  # ---- Serialise symbol section ----
  sym_raw_list <- lapply(seq_len(n_fields), function(j) {
    encode_symbols(sym_list[[j]], type_codes[j])
  })
  sym_section <- do.call(c, sym_raw_list)

  # Field byte offsets and lengths in symbol section
  field_sym_lengths <- sapply(sym_raw_list, length)
  field_sym_offsets <- c(0L, cumsum(field_sym_lengths[-n_fields]))

  # ---- Serialise data section ----
  record_byte_size <- max(1L, ceiling(sum(bit_widths) / 8L))
  # Align to next byte boundary
  data_raw <- encode_records(index_mat, bit_widths, n_records, record_byte_size)

  # ---- Compute biases (bias = -1 so index 0 is null, symbols start at 1) ----
  biases <- rep(-1L, n_fields)

  # ---- Build XML header ----
  field_xml <- mapply(function(name, boff, bw, bias, nsym, off, len, tc) {
    type_str <- switch(as.character(tc),
      "1"  = "INTEGER",
      "2"  = "REAL",
      "4"  = "ASCII",
      "ASCII"
    )
    bit_offset_val <- boff
    sprintf(
      "    <QvdFieldHeader>\n      <FieldName>%s</FieldName>\n      <BitOffset>%d</BitOffset>\n      <BitWidth>%d</BitWidth>\n      <Bias>%d</Bias>\n      <NoOfSymbols>%d</NoOfSymbols>\n      <Offset>%d</Offset>\n      <Length>%d</Length>\n      <Type>%s</Type>\n      <Tags/>\n    </QvdFieldHeader>",
      name, bit_offset_val, bw, bias, nsym, off, len, type_str
    )
  },
    name  = field_names,
    boff  = c(0L, cumsum(bit_widths[-n_fields])),
    bw    = bit_widths,
    bias  = biases,
    nsym  = sapply(sym_list, length),
    off   = field_sym_offsets,
    len   = field_sym_lengths,
    tc    = type_codes,
    SIMPLIFY = TRUE
  )

  xml_str <- sprintf(
'<?xml version="1.0" encoding="UTF-8"?>
<QvdTableHeader>
  <TableName>%s</TableName>
  <CreatedDate>%s</CreatedDate>
  <NoOfRecords>%d</NoOfRecords>
  <RecordByteSize>%d</RecordByteSize>
  <Offset>%d</Offset>
  <Fields>
%s
  </Fields>
</QvdTableHeader>',
    table_name,
    format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
    n_records,
    record_byte_size,
    length(sym_section),
    paste(field_xml, collapse = "\n")
  )

  # ---- Write file ----
  con <- file(path, "wb")
  on.exit(close(con), add = TRUE)
  writeBin(charToRaw(xml_str), con)
  writeBin(as.raw(0x00), con)           # null terminator
  writeBin(sym_section, con)
  writeBin(data_raw, con)

  invisible(path)
}


#' Encode a vector of symbol values as raw bytes
#' @keywords internal
encode_symbols <- function(syms, type_code) {
  if (length(syms) == 0L) return(raw(0))

  parts <- lapply(syms, function(s) {
    switch(as.character(type_code),
      "1" = c(as.raw(0x01), int32_to_raw(as.integer(s))),
      "2" = c(as.raw(0x02), dbl_to_raw(as.double(s))),
      "4" = c(as.raw(0x04), charToRaw(as.character(s)), as.raw(0x00)),
      c(as.raw(0x04), charToRaw(as.character(s)), as.raw(0x00))
    )
  })
  do.call(c, parts)
}


#' Encode int32 as 4-byte little-endian raw vector
#' @keywords internal
int32_to_raw <- function(x) {
  x  <- as.integer(x)
  buf <- raw(4)
  for (i in 1:4) {
    buf[i] <- as.raw(bitwAnd(x, 0xFFL))
    x <- bitwShiftR(x, 8L)
  }
  buf
}


#' Encode double as 8-byte little-endian raw vector
#' @keywords internal
dbl_to_raw <- function(x) {
  writeBin(as.double(x), raw(), size = 8, endian = "little")
}


#' Encode the record matrix as bit-packed raw bytes
#' @keywords internal
encode_records <- function(index_mat, bit_widths, n_records, record_byte_size) {
  total_bytes <- n_records * record_byte_size
  buf <- raw(total_bytes)

  for (r in seq_len(n_records)) {
    row_start_byte <- (r - 1L) * record_byte_size
    bit_cursor     <- 0L

    for (j in seq_len(ncol(index_mat))) {
      bw  <- bit_widths[j]
      if (bw == 0L) next

      # index_mat stores 0-based raw index; null (-1) becomes 0 (bias will shift)
      raw_idx <- index_mat[r, j]
      # null sentinel: raw_idx = -1 => stored as 0 (since bias=-1, 0+(-1)+1=0 => NA)
      stored <- if (raw_idx < 0L) 0L else raw_idx + 1L  # shift: 0 reserved for null

      byte_pos <- row_start_byte + bit_cursor %/% 8L
      bit_pos  <- bit_cursor %% 8L

      # Write bits into buffer (little-endian bit order)
      remaining <- bw
      val       <- stored
      bp        <- bit_pos

      while (remaining > 0L) {
        bits_in_this_byte <- min(remaining, 8L - bp)
        mask_val          <- bitwAnd(val, bitwShiftL(1L, bits_in_this_byte) - 1L)
        # IMPORTANT: Wrap the bitwOr() result with as.raw(). The bitwise OR operation
        # combines the existing byte value with the new bits, but bitwOr() returns an integer.
        # We must convert to raw before assigning to a raw vector, otherwise R will raise:
        # "incompatible types (from integer to raw) in subassignment type fix"
        buf[byte_pos + 1L] <- as.raw(bitwOr(
          as.integer(buf[byte_pos + 1L]),
          as.integer(as.raw(bitwShiftL(mask_val, bp)))
        ))
        val       <- bitwShiftR(val, bits_in_this_byte)
        remaining <- remaining - bits_in_this_byte
        byte_pos  <- byte_pos + 1L
        bp        <- 0L
      }

      bit_cursor <- bit_cursor + bw
    }
  }

  buf
}
