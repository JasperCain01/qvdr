# Base image: rocker/verse supplies R 4.4, tidyverse, knitr, rmarkdown, and
# quarto in a single Ubuntu 22.04 layer — appropriate because this package's
# DESCRIPTION Suggests knitr + rmarkdown for its vignette.
FROM rocker/verse:4.4

# ---------------------------------------------------------------------------
# System libraries
# ---------------------------------------------------------------------------
# libgomp1  – OpenMP runtime required by src/Makevars:
#               PKG_CXXFLAGS = $(SHLIB_OPENMP_CXXFLAGS)
#               PKG_LIBS     = $(SHLIB_OPENMP_CXXFLAGS)
#             gcc/g++ arrive with the image; libgomp1 is the corresponding
#             runtime that must be present at package load time.
# libxml2-dev – required by the xml2 R package (already present in
#               rocker/verse, listed here for explicitness).
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libgomp1 \
        libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# R packages
# ---------------------------------------------------------------------------
# install2.r comes from the littler package bundled with rocker images.
# --error   : fail the build if any package fails to install.
# --skipinstalled : treat already-installed packages as no-ops (safe to
#             re-run; rocker/verse already ships dplyr, knitr, rmarkdown, etc.)
#
# DESCRIPTION Imports (runtime dependencies):
RUN install2.r --error --skipinstalled \
    Rcpp \
    xml2 \
    tibble \
    cli \
    rlang

# DESCRIPTION Suggests (testing, vignette, benchmarking):
RUN install2.r --error --skipinstalled \
    testthat \
    covr \
    knitr \
    rmarkdown \
    dplyr \
    bench

# Development tools inferred from DESCRIPTION (RoxygenNote: 7.3.3) and
# the R-CMD-check GitHub Actions workflow:
RUN install2.r --error --skipinstalled \
    roxygen2 \
    rcmdcheck \
    devtools

# ---------------------------------------------------------------------------
# Notes on packages NOT installed here
# ---------------------------------------------------------------------------
# All dependencies above are sourced from CRAN.  No GitHub-only packages
# were identified in DESCRIPTION, NAMESPACE, or the R source tree.
# If a GitHub-only package is added in future, install it with:
#   RUN Rscript -e "remotes::install_github('owner/repo@ref')"
# and add a comment explaining why CRAN cannot be used.
