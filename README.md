# qvdr: Read QVD Files from QlikView and Qlik Sense

<!-- High-level package introduction -->
qvdr is an R package that reads QVD (QlikView Data) binary files into R tibbles. QVD is Qlik's proprietary columnar data format designed for fast, efficient storage and retrieval. This package handles all the complexity of parsing QVD's three-part binary structure, making it simple to load Qlik data directly into R.

## What are QVD Files?

QVD (QlikView Data) is a binary format used by QlikView and Qlik Sense for high-performance data storage. It's optimized for speed and compression, using a dictionary-encoded columnar layout that allows Qlik applications to load data extremely quickly. QVD files are commonly used for:

- **Data warehousing**: Storing intermediate results from ETL pipelines
- **Incremental updates**: Using metadata to load only changed records
- **Fast analytics**: Pre-aggregated data cubes and fact tables
- **Data interchange**: Moving data between Qlik applications or exporting to other tools

## How qvdr Works

QVD files are organized in three main sections. qvdr reads and converts each section into R data:

### 1. File Header (Metadata)
<!-- Read field names, types, and layout information -->
The file starts with a header that describes the data: field names, data types (numbers, text, dates), and how many rows and columns exist. qvdr reads this first to understand what data is coming.

### 2. Dictionary of Unique Values
<!-- Build lookup table for each column's values -->
Instead of storing the same value over and over, QVD files store each unique value once in a dictionary. For example, if a column has "New York" 50,000 times, it's stored once in the dictionary, and then referenced 50,000 times by its position. This saves a lot of space.

qvdr reads this dictionary for each column and prepares to look up values as needed.

### 3. The Actual Data
<!-- Map dictionary references to actual values and convert to R types -->
The data itself is stored very compactly as references to the dictionary. For example, instead of "New York", the data might just store "3" (meaning "the 3rd value in the dictionary"). 

qvdr uses C++ code (for speed) to read these references and look up the actual values from the dictionary. It then converts the data to R's native formats—turning Qlik dates into R `Date` objects, numbers into numeric vectors, etc.

## Installation

```r
# Install from GitHub (once the package is published)
remotes::install_github("JasperCain01/qvdr")

# Or build locally
devtools::install()
```

## Quick Start

```r
library(qvdr)

# Read an entire QVD file
df <- read_qvd("sales_data.qvd")

# Read only specific columns
df <- read_qvd("sales_data.qvd", col_select = c("Date", "Amount", "Region"))

# Read a sample: first 10,000 rows
df <- read_qvd("sales_data.qvd", n_max = 10000)

# Inspect metadata without loading data
meta <- qvd_metadata("sales_data.qvd")
print(meta$fields)

# Get field names quickly
fields <- qvd_fields("sales_data.qvd")

# See detailed schema with inferred R types
schema <- qvd_schema("sales_data.qvd")
print(schema)
```

## Features

- **Fast parsing**: C++ backend for bit extraction and symbol table parsing
- **Type inference**: Automatically converts QVD types to R equivalents (Date, POSIXct, integer, double, character)
- **Semantic tags**: Respects Qlik semantic metadata (`$date`, `$timestamp`) for proper type conversion
- **Selective loading**: Load only needed columns or rows to reduce memory usage
- **Metadata-only mode**: Read file metadata without loading any data
- **Rich schema info**: Inspect field types, distinct value counts, and bit widths

## Type Mapping

QVD types are mapped to R types as follows:

| QVD Type / Tag | R Type | Notes |
|---|---|---|
| INTEGER | `integer` | 32-bit signed integers |
| REAL | `double` | IEEE 754 floating point |
| ASCII (string) | `character` | UTF-8 encoded strings |
| `$date` tag | `Date` | Days since 1899-12-30 (Excel epoch) |
| `$timestamp` tag | `POSIXct` | Days + fraction since 1899-12-30, UTC timezone |
| `$time` tag | `numeric` | Seconds since midnight |
| Mixed/Dual types | `character` | Falls back to string representation |

## Performance

Reading a typical 1 million-row, 20-column QVD file completes in 1–3 seconds on a modern machine, depending on compression and hardware.

## License

MIT

## Contributing

Contributions are welcome! Please open issues or submit pull requests on [GitHub](https://github.com/JasperCain01/qvdr).
