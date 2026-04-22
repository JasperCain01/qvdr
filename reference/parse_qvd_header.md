# Parse the QVD XML header from a binary connection

Parse the QVD XML header from a binary connection

## Usage

``` r
parse_qvd_header(con)
```

## Arguments

- con:

  An open binary file connection positioned at byte 0.

## Value

A list with elements:

- `fields`: list of field metadata lists

- `n_records`: integer, number of data records

- `record_byte_size`: integer, bytes per record in data section

- `symbol_byte_size`: integer, total bytes in symbol section

- `header_byte_size`: integer, size of the header (for seeking)

- `raw_xml`: character, the raw XML string

- `table_name`: character

- `created_date`: character
