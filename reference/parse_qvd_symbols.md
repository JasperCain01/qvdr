# Parse the QVD symbol table section

Reads the full symbol section from the connection, dispatches to the C++
parser, and assembles typed R vectors for each field.

## Usage

``` r
parse_qvd_symbols(
  con,
  fields,
  symbol_byte_size,
  numeric_as_num = TRUE,
  int_as_int = TRUE
)
```

## Arguments

- con:

  Open binary connection, positioned at start of symbol section.

- fields:

  Field metadata list from
  [`parse_qvd_header()`](https://yourname.github.io/qvdr/reference/parse_qvd_header.md).

- symbol_byte_size:

  Total byte length of the symbol section.

- numeric_as_num:

  Logical; if TRUE, numeric symbols return as double vectors.

- int_as_int:

  Logical; if TRUE, integer symbols return as integer vectors.

## Value

A named list of vectors (one per field), typed appropriately.
