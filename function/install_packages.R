# All the packages from the rocker/geospatial image are already included.
# The full list is https://github.com/rocker-org/geospatial

# For some reason `geojsonio` is not yet in rocker/geospatial. 
# Remove from below if you don't need it.
install.packages(c('geojsonio', 
                   'jsonlite',
                   'ranger',
                   'httr',
                   'devtools'))
library(devtools)
install_github("disarm-platform/disarm")
install_github("tlverse/hal9001", build_vignettes = FALSE)
