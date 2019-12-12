function(params) {
  if (is.null(params[['point_data']])) {
    stop('Missing `point_data` parameter')
  }
  
  if(is.null(params[['exceedance_threshold']]) &
     params[['uncertainty_fieldname']]=="exceedance_uncertainty"){
    stop('"exceedance_threshold" required if using "exceedance_uncertainty" to adaptively select samples')
  }
  
  if(!is.null(params[['exceedance_threshold']]) &
     params[['uncertainty_fieldname']]!="exceedance_uncertainty"){
    stop('"exceedance_threshold" ignored as using "prevalence_bci_width" to adaptively select samples')
  }
}