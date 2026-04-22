#include <Rcpp.h>
using namespace Rcpp;

// ---------------------------------------------------------------------------
// qvd_extract.cpp
//
// High-performance bit-packed index extraction for QVD record matrices.
//
// QVD stores each row as `record_byte_size` bytes. Within each row, each
// field occupies `bit_width` bits starting at `bit_offset` from the row
// start (little-endian bit ordering). The extracted integer is a 0-based
// index into the field's symbol table, adjusted by `bias`.
//
// A bias of -1 means index 0 => NA (null sentinel); symbol[1] is the first
// real value. We map these to NA in the output.
// ---------------------------------------------------------------------------

//' Extract bit-packed symbol indices for a single field across all records
//'
//' @param raw_data  Raw vector containing the entire data section
//' @param n_records Number of records
//' @param record_byte_size Bytes per record (from QVD header)
//' @param bit_offset Bit offset of this field within each record
//' @param bit_width  Number of bits used for this field's index
//' @param bias       Additive bias for the index (often -1, making 0 = NULL)
//' @return Integer vector of 1-based symbol indices (NA where null)
//' @keywords internal
// [[Rcpp::export]]
IntegerVector extract_bits_cpp(
    RawVector   raw_data,
    int         n_records,
    int         record_byte_size,
    int         bit_offset,
    int         bit_width,
    int         bias
) {
  IntegerVector result(n_records, NA_INTEGER);

  if (bit_width == 0) {
    // All values are the same; index is always 0 + bias + 1 (R 1-based)
    int sym_idx = 0 + bias + 1;  // will be 0 when bias=-1 => NA
    for (int r = 0; r < n_records; ++r) {
      result[r] = (sym_idx < 1) ? NA_INTEGER : sym_idx;
    }
    return result;
  }

  // Pre-compute mask for bit_width bits
  uint32_t mask = (bit_width >= 32) ? 0xFFFFFFFFu
                                     : ((1u << bit_width) - 1u);

  int total_bytes = raw_data.size();

  for (int r = 0; r < n_records; ++r) {
    // Absolute bit position in the raw_data buffer
    long long row_start_bit = (long long)r * record_byte_size * 8;
    long long abs_bit       = row_start_bit + bit_offset;

    int byte_idx  = (int)(abs_bit / 8);
    int bit_in_byte = (int)(abs_bit % 8);

    // Accumulate up to 5 bytes (handles up to 32-bit fields spanning byte
    // boundaries with up to 7 leading bits of offset)
    uint64_t accum = 0;
    int bytes_needed = (bit_in_byte + bit_width + 7) / 8;
    bytes_needed = std::min(bytes_needed, 5);

    for (int b = 0; b < bytes_needed; ++b) {
      int bi = byte_idx + b;
      if (bi >= total_bytes) break;
      accum |= ((uint64_t)(unsigned char)raw_data[bi]) << (b * 8);
    }

    // Shift right to align field, then mask
    uint32_t idx = (uint32_t)((accum >> bit_in_byte) & mask);

    // Apply bias: bias converts 0-based QVD index to 0-based symbol index.
    // A bias of -1 means QVD index 0 => null (NA).
    int sym_idx = (int)idx + bias + 1;  // +1 for R's 1-based indexing

    result[r] = (sym_idx < 1) ? NA_INTEGER : sym_idx;
  }

  return result;
}


//' Parse null-terminated strings from a raw vector starting at offset
//'
//' @param raw_data Raw vector of the symbol section
//' @param offsets  Integer vector of byte offsets where each string starts
//' @return Character vector of parsed strings
//' @keywords internal
// [[Rcpp::export]]
CharacterVector parse_strings_cpp(RawVector raw_data, IntegerVector offsets) {
  int n = offsets.size();
  CharacterVector result(n);
  int total = raw_data.size();

  for (int i = 0; i < n; ++i) {
    int start = offsets[i];
    if (start < 0 || start >= total) {
      result[i] = NA_STRING;
      continue;
    }
    // Find null terminator
    int end = start;
    while (end < total && raw_data[end] != 0x00) ++end;

    // Build string from bytes
    std::string s;
    s.reserve(end - start);
    for (int j = start; j < end; ++j) {
      s += (char)(unsigned char)raw_data[j];
    }
    result[i] = s;
  }

  return result;
}


//' Read a little-endian int32 from a raw vector at position pos
//' @keywords internal
// [[Rcpp::export]]
int read_int32_le(RawVector raw_data, int pos) {
  if (pos + 3 >= raw_data.size()) return NA_INTEGER;
  uint32_t val = (uint32_t)(unsigned char)raw_data[pos]
               | ((uint32_t)(unsigned char)raw_data[pos+1] << 8)
               | ((uint32_t)(unsigned char)raw_data[pos+2] << 16)
               | ((uint32_t)(unsigned char)raw_data[pos+3] << 24);
  return (int)val;
}


//' Read a little-endian double from a raw vector at position pos
//' @keywords internal
// [[Rcpp::export]]
double read_double_le(RawVector raw_data, int pos) {
  if (pos + 7 >= (int)raw_data.size()) return NA_REAL;
  unsigned char buf[8];
  for (int i = 0; i < 8; ++i) buf[i] = (unsigned char)raw_data[pos + i];
  double val;
  std::memcpy(&val, buf, 8);
  return val;
}


//' Parse the entire symbol section for all fields at once (fast path)
//'
//' Returns a list of raw symbol buffers and type codes per field for
//' further processing in R. This avoids repeated connection reads.
//'
//' @param raw_symbols  Raw vector containing the entire symbol section
//' @param num_symbols  Integer vector: number of symbols per field
//' @return List of lists, each with elements: types (int), int_vals,
//'         dbl_vals, str_starts (byte offsets into raw_symbols)
//' @keywords internal
// [[Rcpp::export]]
List parse_symbol_section_cpp(RawVector raw_symbols, IntegerVector num_symbols) {
  int n_fields = num_symbols.size();
  int total    = raw_symbols.size();
  int pos      = 0;

  List result(n_fields);

  for (int f = 0; f < n_fields; ++f) {
    int n = num_symbols[f];

    IntegerVector types(n);
    IntegerVector int_vals(n, NA_INTEGER);
    NumericVector dbl_vals(n, NA_REAL);
    IntegerVector str_starts(n, -1);  // byte offset in raw_symbols

    for (int s = 0; s < n; ++s) {
      if (pos >= total) {
        Rcpp::stop("Unexpected end of symbol section at field %d, symbol %d", f+1, s+1);
      }
      int type = (unsigned char)raw_symbols[pos++];
      types[s] = type;

      switch (type) {
        case 0x01: {  // int32
          if (pos + 3 >= total) Rcpp::stop("Truncated int32 at pos %d", pos);
          int_vals[s] = read_int32_le(raw_symbols, pos);
          pos += 4;
          break;
        }
        case 0x02: {  // double
          if (pos + 7 >= total) Rcpp::stop("Truncated double at pos %d", pos);
          dbl_vals[s] = read_double_le(raw_symbols, pos);
          pos += 8;
          break;
        }
        case 0x04: {  // string (null-terminated)
          str_starts[s] = pos;
          while (pos < total && raw_symbols[pos] != 0x00) ++pos;
          pos++;  // consume null
          break;
        }
        case 0x05: {  // dual: int32 + string
          if (pos + 3 >= total) Rcpp::stop("Truncated dual-int at pos %d", pos);
          int_vals[s] = read_int32_le(raw_symbols, pos);
          pos += 4;
          str_starts[s] = pos;
          while (pos < total && raw_symbols[pos] != 0x00) ++pos;
          pos++;
          break;
        }
        case 0x06: {  // dual: double + string
          if (pos + 7 >= total) Rcpp::stop("Truncated dual-dbl at pos %d", pos);
          dbl_vals[s] = read_double_le(raw_symbols, pos);
          pos += 8;
          str_starts[s] = pos;
          while (pos < total && raw_symbols[pos] != 0x00) ++pos;
          pos++;
          break;
        }
        default:
          Rcpp::stop("Unknown symbol type 0x%02X at field %d, symbol %d", type, f+1, s+1);
      }
    }

    result[f] = List::create(
      Named("types")      = types,
      Named("int_vals")   = int_vals,
      Named("dbl_vals")   = dbl_vals,
      Named("str_starts") = str_starts
    );
  }

  return result;
}
