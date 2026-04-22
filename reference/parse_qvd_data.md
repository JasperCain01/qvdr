# Parse the QVD data section into a data frame

Parse the QVD data section into a data frame

## Usage

``` r
parse_qvd_data(con, header, symbol_table, col_select = NULL, verbose = TRUE)
```

## Arguments

- con:

  Open binary connection at the start of the data section.

- header:

  Parsed header from
  [`parse_qvd_header()`](https://yourname.github.io/qvdr/reference/parse_qvd_header.md).

- symbol_table:

  Named list of symbol vectors from
  [`parse_qvd_symbols()`](https://yourname.github.io/qvdr/reference/parse_qvd_symbols.md).

- col_select:

  Character vector of column names to return, or NULL for all.

- verbose:

  Logical; print progress bar.

## Value

A tibble.
