# Parse the entire symbol section for all fields at once (fast path)

Returns a list of raw symbol buffers and type codes per field for
further processing in R. This avoids repeated connection reads.

## Usage

``` r
parse_symbol_section_cpp(raw_symbols, num_symbols)
```

## Arguments

- raw_symbols:

  Raw vector containing the entire symbol section

- num_symbols:

  Integer vector: number of symbols per field

## Value

List of lists, each with elements: types (int), int_vals, dbl_vals,
str_starts (byte offsets into raw_symbols)
