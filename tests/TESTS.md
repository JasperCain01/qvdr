# What the tests protect

There are 27 `test_that()` blocks in `tests/testthat/`. Run them with `devtools::test()`; they also run under `R CMD check` and the coverage workflow in CI.

## Read this first: what these tests can and cannot prove

All fixtures except one are written by the package's own `qvdr:::write_test_qvd()` and then read back with `read_qvd()`. Those tests prove the reader and the writer **agree with each other**. They don't prove either agrees with Qlik. If both shared a misreading of the format (bit-packing order, bias, null representation, symbol type codes), every round-trip test would pass while real files decoded wrongly.

The writer also differs from Qlik in two known ways:

- It puts each field's `<Type>` directly under `<QvdFieldHeader>`, where Qlik nests it under `<NumberFormat>`. `parse_header.R` checks both places, so synthetic fixtures exercise a branch real files never take.
- It writes only plain integer, double and string symbols, never the dual-value types Qlik uses for dates and timestamps.

Only `test-real-qvd.R`, which reads a 10-row file exported from QlikSense, checks the reader against reality. That file has no nulls, no field with more than 255 distinct values, and only the column types listed below. Real exports covering those cases are tracked in [issue #2](https://github.com/JasperCain01/qvdr/issues/2).

**Locale:** `parse_qvd_header()` converts the header bytes to text in the session's locale. Under a non-UTF-8 locale (for example `LANG` unset on a Linux server), a header containing non-ASCII text fails to parse. The real fixture's `£` currency format triggers this. Run the suite under a UTF-8 locale; CI does. This is a package bug rather than a test problem, and `test-real-qvd.R` is the test that exposes it.

Severity describes what goes wrong for a user if the guarded behaviour breaks:

- **Critical**: files can't be read.
- **High**: plausible-looking but wrong data is returned.
- **Medium**: a feature visibly fails or errors.
- **Low**: a message is wrong.

## `test-real-qvd.R`: agreement with real Qlik output

These are the most important tests in the package. They must never be skipped, and the file is committed.

| Test | Purpose | Severity |
|---|---|---|
| read real QVD file from QlikSense | A Qlik-written file reads with the right dimensions, column names and R types (Date, numeric, character, POSIXct). | Critical |
| read real QVD has correct date values | Date fields decode to the right calendar dates. | High |
| read real QVD has correct numeric values | Integer and currency fields decode to their underlying numbers, not their display strings. | High |
| read real QVD has correct text values | String fields decode in order. | High |
| read real QVD has correct timestamp values | Timestamp fields decode to the right instant in UTC. | High |

## `test-read_qvd.R`: values, order, selection and limits

| Test | Purpose | Severity |
|---|---|---|
| read_qvd returns the written table exactly | For an integer/string fixture and a double fixture, the result is identical to the source data: names, column types, values and row order in one comparison. | High |
| NULL values come back as NA in the right cells | Nulls land in the right rows for string and integer columns, and an all-null column keeps its length and type. Misplaced nulls shift data between records. | High |
| a large multi-column file round-trips exactly | 5,000 rows across five fields, with an ID field that needs a 13-bit index, compared exactly and unsorted. This exercises bit-unpacking across field and byte boundaries, where an off-by-one would shuffle or corrupt rows. | High |
| a field with a single distinct value is read for every row | A constant column has a zero-width index, an edge case of the bit-unpacking code. | High |
| col_select returns the requested columns in file row order | Selecting one or two columns gives exactly those columns with rows unchanged, and unknown names among known ones are ignored. | Medium |
| col_select errors when nothing requested exists | The error names the missing column. | Low |
| n_max limits rows to the first n | `n_max = 0` keeps the schema, `n_max = 3` gives the first three rows exactly, and a limit larger than the file returns everything. | Medium |
| verbose = FALSE suppresses progress messages | Quiet mode is quiet. | Low |

## `test-type-coercion.R`: types and value fidelity

`expect_identical()` is used throughout. An earlier version compared `as.integer(result$X)` with the source, which passed even when the column came back as character.

| Test | Purpose | Severity |
|---|---|---|
| integers come back as integers with their exact values | Negative, zero and large values; integer type. | High |
| doubles come back as doubles with their exact values | Values from −1e10 to 1e10, including small fractions, with no precision loss. | High |
| strings come back as character | Spaces, `/`, `%`, `=` and the empty string survive. | High |
| int_as_int = FALSE returns double for integer columns | The documented opt-out works. | Medium |
| numeric_as_num = FALSE returns every column as character | The documented opt-out works. | Medium |

## `test-metadata.R`: describing a file without reading its data

| Test | Purpose | Severity |
|---|---|---|
| qvd_metadata describes the table, its fields and its record count | The returned list has its documented elements, with the right table name, counts, field names and raw header XML. | Medium |
| qvd_fields returns the field names in file order | | Medium |
| qvd_schema returns one row per field with its distinct-value count | The schema tibble has its documented columns, and `n_distinct` counts distinct values rather than rows. | Medium |

## `test-edge-cases.R`: degenerate shapes, bad input, damaged files

| Test | Purpose | Severity |
|---|---|---|
| degenerate shapes read correctly | A file with no records gives an empty tibble with the right columns; one-row and one-column files read exactly. | Medium |
| a missing file is reported as not found by every reader | All four entry points give the same clear error. | Low |
| a path that is not a single string is rejected | Non-character, `NULL` and multi-element paths fail with a clear message. | Low |
| a QVD with a non-.qvd extension is read, with a warning | A misnamed file is still read rather than refused. | Medium |
| a truncated or corrupt file never returns data without saying so | A real file cut short in the header or symbol table is an error; cut short in the data section, it warns and returns exactly the complete records; non-QVD bytes are an error. This pins today's contract, so a future change can't start returning partial or garbled data quietly. | High |
| format_bytes reports file sizes in the unit a person would use | The helper used in verbose output. | Low |
