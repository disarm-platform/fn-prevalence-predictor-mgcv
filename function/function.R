suppressPackageStartupMessages(library(sf))
library(geojsonio)
library(httr)
library(sp) 
library(mgcv) 
library(RANN)

gam_posterior_metrics <- dget('function/gam_posterior_metrics.r')
cv_ml <- dget('function/cv_ml.r')
optimal_range <- dget('function/optimal_range.r')


function(params) {
    
    # Set defaults
    if(!is.null(params$seed)){
      seed <- params$seed
    }else{
      seed <- 1
    }
    set.seed(seed)
    
    if(!is.null(params$v)){
      v <- params$v
    }else{
      v <- 10
    }
    
    if(is.null(params$covariate_extractor_url)){
      covariate_extractor_url <- "https://faas.srv.disarm.io/function/fn-covariate-extractor"
    }else{
      covariate_extractor_url <- params$covariate_extractor_url
    }
    
    # Read into memory
    point_data <- st_read(rjson::toJSON(params$point_data), quiet = T)
    
    # define params function
    layer_names = unlist(params$layer_names)
    additional_covariates = unlist(params$additional_covariates)
    exceedance_threshold = params$exceedance_threshold
    batch_size = params$batch_size
    uncertainty_fieldname = params$uncertainty_fieldname
    
    # Run some checks
    if(!(uncertainty_fieldname %in% c("exceedance_probability", "prevalence_bci_width"))){
      stop("'uncertainty_fieldname' must be either 'exceedance_probability' or 'prevalence_bci_width'")
    }
    
    if(!is.null(additional_covariates) | !is.null(layer_names)){
      
      if(!is.null(layer_names)){ 
        
        # Send to covariate_extractor
        cov_ext_input_data_list <- list(points = geojson_list(point_data),
                                        layer_names = layer_names)
        
        
        response <-
          httr::POST(
            url = covariate_extractor_url,
            body = as.json(cov_ext_input_data_list),
            content_type_json(),
            timeout(90)
          )
        
        # Get contents of the response
        response_content <- content(response)
        
        points_sf <- st_read(as.json(response_content$result), quiet = TRUE)
        points_sf$n_trials <- as.numeric(as.character(points_sf$n_trials))
        points_sf$n_positive <- as.numeric(as.character(points_sf$n_positive))
      }
      
      # Pass into cv-ml
      response_content <- cv_ml(points_sf, layer_names = c(layer_names, additional_covariates),
                                k=v)
      
      # Now fit GAM model to cv predictions
      mod_data_sf <- response_content$points
      mod_data <- as.data.frame(response_content$points)
      mod_data <- cbind(mod_data, st_coordinates(mod_data_sf))
      mod_data$n_neg <- mod_data$n_trials - mod_data$n_positive
      train_data <- mod_data[!is.na(mod_data$n_trials),]
      
      # Choose k
      k <- floor(nrow(train_data)*0.9)
      if(k > 200){
        k <- 200
      }
      
      opt_range <- optimal_range(y = "cbind(n_positive, n_neg)", 
                                 x = "cv_predictions_logit",
                                 coords_cols = c("X", "Y"),
                                 min_dist  = min(diff(range(train_data$X)), diff(range(train_data$Y)))/100, 
                                 max_dist = max(min(diff(range(train_data$X)), diff(range(train_data$Y))))/2, 
                                 length.out = 10, 
                                 model_data = train_data, 
                                 k=k)
      
      gam_mod <- gam(cbind(n_positive, n_neg) ~ cv_predictions_logit +
                       s(X, Y, bs="gp", k=k, m=c(3, opt_range$best_m)),
                     data = train_data,
                     family="binomial")
      
    }else{
      # Choose k
      mod_data <- as.data.frame(point_data)
      mod_data <- cbind(mod_data, st_coordinates(point_data))
      mod_data$n_neg <- mod_data$n_trials - mod_data$n_positive
      train_data <- mod_data[!is.na(mod_data$n_trials),]
      #pred_data <- mod_data[is.na(mod_data$n_trials),]
      k <- floor(nrow(train_data)*0.9)
      if(k > 200){
        k <- 200
      }
      
      opt_range <- optimal_range(y = "cbind(n_positive, n_neg)",
                                 coords_cols = c("X", "Y"),
                                 min_dist  = min(diff(range(train_data$X)), diff(range(train_data$Y)))/100,
                                 max_dist = max(min(diff(range(train_data$X)), diff(range(train_data$Y))))/2,
                                 length.out = 20,
                                 model_data = train_data,
                                 k=k)
      
      gam_mod <- gam(cbind(n_positive, n_neg) ~
                       s(X, Y, bs="gp", k=k, m=c(3, opt_range$best_m)),
                     data = train_data,
                     family="binomial")
    }    
    
    # Get posterior metrics
    mod_data$cv_predictions_logit <- mod_data$fitted_predictions_logit
    posterior_metrics <- gam_posterior_metrics(gam_mod,
                                               mod_data,
                                               500,
                                               exceedance_threshold)
    
    # Bind to point_data
    for(i in names(posterior_metrics)){
      point_data[[i]] <- posterior_metrics[[i]]
    }
    
    # If batch_size is specitfied, then perform adaptive sampling
    if(!is.null(batch_size)){
      
      if(uncertainty_fieldname == 'exceedance_probability'){
        uncertainty_fieldname = 'exceedance_uncertainty'
      }
      
      # new_batch_idx <- choose_batch_simple(point_data = point_data, 
      #                     batch_size = batch_size,
      #                     uncertainty_fieldname = uncertainty_fieldname,
      #                     candidate = is.na(point_data$n_trials))
      
      new_batch_idx <- choose_batch(st_coordinates(point_data),
                                    entropy = point_data$entropy,
                                    candidate = is.na(point_data$n_positive),
                                    rho = 1 / opt_range$best_m,
                                    nu = 1.5,
                                    batch_size = batch_size)
      
      
      # chosen <- FALSE
      # delta <- opt_range$best_m
      # criterion <- ifelse(uncertainty_fieldname=="exceedance_probability",
      #                     "exceedprob", "predvar")
      # if(criterion == "exceedprob"){
      #   excd.prob.col = "exceedance_probability"
      #   pred.var.col = NULL
      # }else{
      #   excd.prob.col = NULL
      #   pred.var.col = "prevalence_bci_width"
      # }
      # 
      # # Automatically wind down delta in order to allow batch_size samples to be chosen
      # while(chosen == FALSE){
      #   obj1 <- point_data[is.na(point_data$n_trials),]
      #   obj2 <- point_data[!is.na(point_data$n_trials),]
      #       new_batch <- adaptive_sample_auto(obj1 = obj1,
      #                            obj2 = obj2,
      #                            excd.prob.col = excd.prob.col,
      #                            pred.var.col = pred.var.col,
      #                            batch.size = batch_size,
      #                            delta = delta,
      #                            criterion = criterion,
      #                            poly = NULL,
      #                            plotit = FALSE)
      #       if(nrow(new_batch$sample.locs$added.sample) < batch_size){
      #         delta <- delta*0.9
      #       }else{
      #         chosen <- TRUE
      #       }
      # }
      # 
      # # Get indeces of those adaptively selected
      # nearest <- RANN::nn2(st_coordinates(new_batch$sample.locs$added.sample),
      #                            st_coordinates(obj1), k=1)
      # new_batch_idx <- which(nearest$nn.dists==0)
      
      # Add adaptively selected column
      point_data$adaptively_selected <- FALSE
      point_data$adaptively_selected[new_batch_idx] <- TRUE
    }
    
    # package and return
    return(geojson_list(point_data))
  
}
