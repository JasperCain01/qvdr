# qvdr: Read QVD Files from QlikView and Qlik Sense

The qvdr package reads QVD (QlikView Data) binary files — Qlik's
proprietary high-performance columnar format — into R tibbles.

### Key functions

- [`read_qvd()`](https://yourname.github.io/qvdr/reference/read_qvd.md):
  Read a QVD file into a tibble (main entry point)

- [`qvd_metadata()`](https://yourname.github.io/qvdr/reference/qvd_metadata.md):
  Read only the header metadata (fast)

- [`qvd_fields()`](https://yourname.github.io/qvdr/reference/qvd_fields.md):
  List field names in a QVD file

- [`qvd_schema()`](https://yourname.github.io/qvdr/reference/qvd_schema.md):
  Get detailed schema including R types and distinct counts

### QVD format notes

A QVD file has three sections:

1.  **XML header**: metadata including field names, types, Qlik tags,
    and layout parameters for the bit-packed data section.

2.  **Symbol table**: per-field dictionaries of all unique values,
    encoded as typed entries (int32, double, or null-terminated string).

3.  **Data section**: a bit-packed record matrix where each row's fields
    are encoded as variable-width indices into the symbol table.

The bit-extraction inner loop is implemented in C++ via
[Rcpp::Rcpp](https://rdrr.io/pkg/Rcpp/man/Rcpp-package.html) for
performance. Reading a 1 million-row, 20-column QVD file typically
completes in 1–3 seconds on a modern machine.

### Type mapping

|                |             |
|----------------|-------------|
| QVD / Qlik tag | R type      |
| INTEGER        | `integer`   |
| REAL / FIX     | `double`    |
| `$date`        | `Date`      |
| `$timestamp`   | `POSIXct`   |
| ASCII (string) | `character` |

## See also

Useful links:

- <https://github.com/yourname/qvdr>

- Report bugs at <https://github.com/yourname/qvdr/issues>

## Author

**Maintainer**: Your Name <you@example.com>
([ORCID](https://orcid.org/0000-0000-0000-0000))
