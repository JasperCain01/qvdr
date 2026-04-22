# Determine the dominant storage type for a field's symbols

Uses the QVD field `type` tag and actual symbol types to decide how to
expose the field in R.

## Usage

``` r
determine_dominant_type(types, field)
```

## Arguments

- types:

  Integer vector of symbol type codes.

- field:

  A single field metadata list.

## Value

One of "integer", "double", "string", "dual_int", "dual_dbl".
