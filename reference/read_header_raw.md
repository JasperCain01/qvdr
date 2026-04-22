# Read the raw header bytes from an open binary connection

Reads until it finds the null byte that terminates the QVD XML header.

## Usage

``` r
read_header_raw(con)
```

## Arguments

- con:

  An open binary file connection, positioned at byte 0.

## Value

A raw vector containing the header bytes (including null terminator).
