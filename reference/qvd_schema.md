# Get the full schema of a QVD file as a tibble

Returns detailed schema information for each field, including inferred R
type, QVD type, Qlik tags, number of distinct values, and bit width.

## Usage

``` r
qvd_schema(path)
```

## Arguments

- path:

  Path to the `.qvd` file.

## Value

A tibble with one row per field and columns: `name`, `r_type`,
`qvd_type`, `tags`, `n_distinct`, `bit_width`.

## Examples

``` r
if (FALSE) { # \dontrun{
schema <- qvd_schema("Sales.qvd")
print(schema)
} # }
```
