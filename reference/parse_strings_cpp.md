# Parse null-terminated strings from a raw vector starting at offset

Parse null-terminated strings from a raw vector starting at offset

## Usage

``` r
parse_strings_cpp(raw_data, offsets)
```

## Arguments

- raw_data:

  Raw vector of the symbol section

- offsets:

  Integer vector of byte offsets where each string starts

## Value

Character vector of parsed strings
