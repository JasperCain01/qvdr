# R/parse_header.R
# ---------------------------------------------------------------------------
# QVD XML header parsing
#
# The QVD header is an XML document at the start of the file, terminated by
# a null byte (0x00) that follows the closing </QvdTableHeader> tag.
# We read byte-by-byte until we find the null, then parse with xml2.
# ---------------------------------------------------------------------------

#' Read the raw header bytes from an open binary connection
#'
#' Reads until it finds the null byte that terminates the QVD XML header.
#'
#' @param con An open binary file connection, positioned at byte 0.
#' @return A raw vector containing the header bytes (including null terminator).
#' @keywords internal
read_header_raw <- function(con) {
  # Read in chunks for efficiency rather than byte-by-byte
  chunk_size <- 4096L
  buf        <- raw(0)
  found      <- FALSE

  while (!found) {
    chunk <- readBin(con, raw(), n = chunk_size)
    if (length(chunk) == 0L) {
      cli::cli_abort("Reached end of file without finding QVD header terminator.")
    }

    buf <- c(buf, chunk)

    # Check if we've passed the closing tag and hit the null byte
    null_pos <- which(buf == as.raw(0x00))
    if (length(null_pos) > 0L) {
      # Rewind the connection to just after the null byte
      target_pos <- null_pos[1L]
      # Seek back to correct position
      seek(con, where = target_pos, origin = "start")
      buf   <- buf[seq_len(target_pos)]
      found <- TRUE
    }
  }

  buf
}


#' Parse the QVD XML header from a binary connection
#'
#' @param con An open binary file connection positioned at byte 0.
#' @return A list with elements:
#'   - `fields`: list of field metadata lists
#'   - `n_records`: integer, number of data records
#'   - `record_byte_size`: integer, bytes per record in data section
#'   - `symbol_byte_size`: integer, total bytes in symbol section
#'   - `header_byte_size`: integer, size of the header (for seeking)
#'   - `raw_xml`: character, the raw XML string
#'   - `table_name`: character
#'   - `created_date`: character
#' @keywords internal
parse_qvd_header <- function(con) {
  raw_bytes <- read_header_raw(con)

  # Strip null byte and trailing whitespace, convert to string
  xml_str <- rawToChar(raw_bytes[raw_bytes != as.raw(0x00)])

  # Parse XML
  doc <- tryCatch(
    xml2::read_xml(xml_str),
    error = function(e) {
      cli::cli_abort(c(
        "Failed to parse QVD XML header.",
        "i" = "The file may be corrupted or not a valid QVD file.",
        "x" = conditionMessage(e)
      ))
    }
  )

  # ---- Top-level metadata ----
  xtext <- function(xpath) {
    node <- xml2::xml_find_first(doc, xpath)
    if (inherits(node, "xml_missing")) return(NA_character_)
    xml2::xml_text(node)
  }

  table_name       <- xtext(".//TableName")
  created_date     <- xtext(".//CreatedDate")
  n_records        <- as.integer(xtext(".//NoOfRecords"))
  record_byte_size <- as.integer(xtext(".//RecordByteSize"))
  symbol_byte_size <- as.integer(xtext(".//Offset"))  # Total symbol section size

  # ---- Field metadata ----
  field_nodes <- xml2::xml_find_all(doc, ".//QvdFieldHeader")

  if (length(field_nodes) == 0L) {
    cli::cli_abort("No fields found in QVD header. File may be empty or corrupt.")
  }

  ftext <- function(node, xpath) {
    n <- xml2::xml_find_first(node, xpath)
    if (inherits(n, "xml_missing")) return(NA_character_)
    xml2::xml_text(n)
  }

  fields <- lapply(field_nodes, function(f) {
    tags_nodes <- xml2::xml_find_all(f, ".//Tags/String")
    tags       <- if (length(tags_nodes) > 0) xml2::xml_text(tags_nodes) else character(0)

    list(
      name             = ftext(f, "FieldName"),
      bit_offset       = as.integer(ftext(f, "BitOffset")),
      bit_width        = as.integer(ftext(f, "BitWidth")),
      bias             = as.integer(ftext(f, "Bias")),
      num_symbols      = as.integer(ftext(f, "NoOfSymbols")),
      offset           = as.integer(ftext(f, "Offset")),   # byte offset in symbol section
      length           = as.integer(ftext(f, "Length")),   # byte length in symbol section
      type             = ftext(f, "Type"),                  # "ASCII", "INTEGER", "REAL", etc.
      tags             = tags,                              # e.g. "$date", "$timestamp"
      number_format    = ftext(f, "NumberFormat/Type"),
      has_undefined    = identical(ftext(f, "HasUndefined"), "true")
    )
  })

  list(
    table_name       = table_name,
    created_date     = created_date,
    n_records        = n_records,
    record_byte_size = record_byte_size,
    symbol_byte_size = symbol_byte_size,
    fields           = fields,
    raw_xml          = xml_str
  )
}
