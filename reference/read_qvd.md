# Read a QVD file into a tibble

Reads a QVD (QlikView Data) binary file and returns its contents as a
tibble. Column types are inferred from QVD metadata: integers, doubles,
dates, timestamps, and strings are all supported.

## Usage

``` r
read_qvd(
  path,
  col_select = NULL,
  n_max = NULL,
  numeric_as_num = TRUE,
  int_as_int = TRUE,
  verbose = TRUE
)
```

## Arguments

- path:

  Path to the `.qvd` file.

- col_select:

  Optional character vector of column names to load. If `NULL`
  (default), all columns are returned.

- n_max:

  Optional integer; maximum number of rows to return. If `NULL`
  (default), all rows are returned.

- numeric_as_num:

  Logical (default `TRUE`). If `TRUE`, purely numeric symbol tables are
  returned as double or integer vectors. If `FALSE`, all columns are
  returned as character.

- int_as_int:

  Logical (default `TRUE`). If `TRUE`, integer symbol tables are
  returned as integer vectors rather than double.

- verbose:

  Logical (default `TRUE`). If `TRUE`, show progress messages and a
  progress bar for large files.

## Value

A [`tibble::tibble`](https://tibble.tidyverse.org/reference/tibble.html)
with one column per field and one row per record. Column types:

- `integer` for fields tagged as integers

- `double` for fields tagged as real numbers

- `Date` for fields tagged `$date`

- `POSIXct` for fields tagged `$timestamp`

- `character` for string fields and mixed types

## Examples

``` r
if (FALSE) { # \dontrun{
# Read all columns
df <- read_qvd("Sales.qvd")

# Read only specific columns
df <- read_qvd("Sales.qvd", col_select = c("SalesDate", "Amount", "Region"))

# Peek at first 1000 rows
df <- read_qvd("Sales.qvd", n_max = 1000)

# Return everything as character (no type coercion)
df <- read_qvd("Sales.qvd", numeric_as_num = FALSE)
} # }
```
