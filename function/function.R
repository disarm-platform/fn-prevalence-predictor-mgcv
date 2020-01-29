suppressPackageStartupMessages(library(sf))
library(geojsonio)
library(disarmr)
  
function(params) {
    
    set.seed(1981)
    # Read into memory
    point_data <- st_read(as.json(params$point_data), quiet = TRUE)
    
    # Run function
    res <- prevalence_predictor_mgcv(point_data = point_data,
                              layer_names = params$layer_names,
                              exceedance_threshold = params$exceedance_threshold,
                              batch_size = params$batch_size,
                              uncertainty_fieldname = params$uncertainty_fieldname)
    
    # package and return
    return(geojson_list(res))
  
}
