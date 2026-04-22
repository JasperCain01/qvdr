# Extract bit-packed symbol indices for a single field across all records

Extract bit-packed symbol indices for a single field across all records

## Usage

``` r
extract_bits_cpp(
  raw_data,
  n_records,
  record_byte_size,
  bit_offset,
  bit_width,
  bias
)
```

## Arguments

- raw_data:

  Raw vector containing the entire data section

- n_records:

  Number of records

- record_byte_size:

  Bytes per record (from QVD header)

- bit_offset:

  Bit offset of this field within each record

- bit_width:

  Number of bits used for this field's index

- bias:

  Additive bias for the index (often -1, making 0 = NULL)

## Value

Integer vector of 1-based symbol indices (NA where null)
