# Read QVD file metadata only (fast, no data loaded)

Reads and parses only the XML header of a QVD file. This is very fast
even for large files since it reads only a few kilobytes.

## Usage

``` r
qvd_metadata(path)
```

## Arguments

- path:

  Path to the `.qvd` file.

## Value

A list with:

- `table_name`: character, the QVD table name

- `created_date`: character, when the file was created

- `n_records`: integer, number of records

- `n_fields`: integer, number of fields

- `fields`: a data frame with one row per field and columns `name`,
  `type`, `tags`, `num_symbols`, `bit_width`

- `raw_xml`: character, the raw XML header string

## Examples

``` r
if (FALSE) { # \dontrun{
meta <- qvd_metadata("Sales.qvd")
cat("Records:", meta$n_records, "\n")
print(meta$fields)
} # }
```
