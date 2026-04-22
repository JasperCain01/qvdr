# Write a synthetic QVD file for testing

Creates a minimal but valid QVD binary file from a data frame. This is
used internally by the test suite to generate fixture files without
requiring a Qlik installation.

## Usage

``` r
write_test_qvd(df, path, table_name = "TestTable")
```

## Arguments

- df:

  A data.frame or tibble.

- path:

  Output path for the `.qvd` file.

- table_name:

  Character; the QVD table name embedded in the header.

## Value

`path`, invisibly.

## Details

Supports integer, double, and character columns. Date/POSIXct columns
are coerced to double (Qlik serial number).
