# Coerce a raw symbol vector to its appropriate R type

Uses QVD field metadata (type, tags, number_format) to produce the most
appropriate R type: integer, double, Date, POSIXct, or character.

## Usage

``` r
coerce_column(vec, field)
```

## Arguments

- vec:

  Vector of raw symbol values (integer, double, or character).

- field:

  Field metadata list.

## Value

A typed R vector.
