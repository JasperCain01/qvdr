pkgname <- "qvdr"
source(file.path(R.home("share"), "R", "examples-header.R"))
options(warn = 1)
library('qvdr')

base::assign(".oldSearch", base::search(), pos = 'CheckExEnv')
base::assign(".old_wd", base::getwd(), pos = 'CheckExEnv')
cleanEx()
nameEx("qvd_fields")
### * qvd_fields

flush(stderr()); flush(stdout())

### Name: qvd_fields
### Title: List field names in a QVD file
### Aliases: qvd_fields

### ** Examples

## Not run: 
##D qvd_fields("Sales.qvd")
##D #> [1] "SalesDate" "ProductID" "Region" "Amount"
## End(Not run)



cleanEx()
nameEx("qvd_metadata")
### * qvd_metadata

flush(stderr()); flush(stdout())

### Name: qvd_metadata
### Title: Read QVD file metadata only (fast, no data loaded)
### Aliases: qvd_metadata

### ** Examples

## Not run: 
##D meta <- qvd_metadata("Sales.qvd")
##D cat("Records:", meta$n_records, "\n")
##D print(meta$fields)
## End(Not run)



cleanEx()
nameEx("qvd_schema")
### * qvd_schema

flush(stderr()); flush(stdout())

### Name: qvd_schema
### Title: Get the full schema of a QVD file as a tibble
### Aliases: qvd_schema

### ** Examples

## Not run: 
##D schema <- qvd_schema("Sales.qvd")
##D print(schema)
## End(Not run)



cleanEx()
nameEx("read_qvd")
### * read_qvd

flush(stderr()); flush(stdout())

### Name: read_qvd
### Title: Read a QVD file into a tibble
### Aliases: read_qvd

### ** Examples

## Not run: 
##D # Read all columns
##D df <- read_qvd("Sales.qvd")
##D 
##D # Read only specific columns
##D df <- read_qvd("Sales.qvd", col_select = c("SalesDate", "Amount", "Region"))
##D 
##D # Peek at first 1000 rows
##D df <- read_qvd("Sales.qvd", n_max = 1000)
##D 
##D # Return everything as character (no type coercion)
##D df <- read_qvd("Sales.qvd", numeric_as_num = FALSE)
## End(Not run)



### * <FOOTER>
###
cleanEx()
options(digits = 7L)
base::cat("Time elapsed: ", proc.time() - base::get("ptime", pos = 'CheckExEnv'),"\n")
grDevices::dev.off()
###
### Local variables: ***
### mode: outline-minor ***
### outline-regexp: "\\(> \\)?### [*]+" ***
### End: ***
quit('no')
