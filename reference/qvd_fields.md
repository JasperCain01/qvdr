# List field names in a QVD file

A lightweight convenience function that returns only the field names
from a QVD file's header, without loading any data.

## Usage

``` r
qvd_fields(path)
```

## Arguments

- path:

  Path to the `.qvd` file.

## Value

A character vector of field names, in the order they appear in the QVD
file.

## Examples

``` r
if (FALSE) { # \dontrun{
qvd_fields("Sales.qvd")
#> [1] "SalesDate" "ProductID" "Region" "Amount"
} # }
```
