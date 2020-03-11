# All the packages from the rocker/geospatial image are already included.
# The full list is https://github.com/rocker-org/geospatial

# For some reason `geojsonio` is not yet in rocker/geospatial. 
# Remove from below if you don't need it.
# install.packages("config",repos="http://cran.us.r-project.org")
# library(config)
install.packages(c('geojsonio',
                   'jsonlite',
                   'devtools',
                   'ranger',
                   'mgcv',
                   'RANN',
                   'httr',
                   'caret',
                   'parallel'))

