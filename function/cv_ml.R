#' Function to fit a 10 fold cross validated ML model. Currently only support binomial data.
#' @name cv_ml
#' @param points A data.frame or sfc object containing `n_trials`, `n_positive` fields
#' @param layer_names Names of column corresponding covariates to use
#' @param model_type Either `randomForest`, in which case a random forest 
#' @param k The number of folds to use
#' @param fix_cov If wishing to fix the values of any covariates when producing fitted values, specify as 
#' list with 2 elements 'cov_name' and 'cov_val' e.g. fix_cov = list(cov_name = 'x', cov_val = 1)
#' using the ranger package is fit or `hal`, in which case
#' a highly adaptive lasso using the hal9001 package is fit. Note the `hal` 
#' is computationally expensive and not recommended for large 
#' (>200) datasets. 
#' @import parallel ranger caret
#' @export

fit_rf_parallel <- dget('function/fit_rf_parallel.R')
folds_list_to_df_list <- dget('function/folds_list_to_df_list.R')

cv_ml <- function(points, layer_names, model_type = "randomforest", k = 20,
                  fix_cov=NULL) {

  seed <- 1981
  points_df <- as.data.frame(points)
  points_df$n_negative <- points_df$n_trials - points_df$n_positive
  
  # Filter out training data
  points_df$row_id <- 1:nrow(points_df)
  with_data <- which(!(is.na(points_df$n_negative)))
  points_df_train <- points_df[with_data,]
  
  # Create folds
  set.seed(seed)
  #folds_list <- origami::make_folds(points_df_train)
  folds_list <- caret::createFolds(points_df_train$n_positive, k=k)
  folds_df_list <- lapply(folds_list, folds_list_to_df_list, df = points_df_train)
  
  # Save validation indeces for later
  valid_indeces <- unlist(folds_list)
  
  
  if(model_type == "randomforest"){
    cv_predictions <- parallel::mclapply(folds_df_list, FUN = fit_rf_parallel,
                                         mc.cores = parallel::detectCores() - 1,
                                         X_var = layer_names,
                                         n_pos_var = "n_positive",
                                         n_neg_var = "n_negative")
    
    # Add cv predictions back onto data.frame
    points_df_train$cv_preds[valid_indeces] <- unlist(cv_predictions)
    
    # Now fit RF to full dataset and create fitted predictions
    Y <- factor(c(rep(0, nrow(points_df_train)),
                  rep(1, nrow(points_df_train))))
    
    X <- as.data.frame(points_df_train[,layer_names])
    X <- rbind(X, X)
    names(X) <- layer_names
    rf_formula <- as.formula(paste("Y", "~", paste(layer_names, collapse = "+")))
    rf_fit <- ranger(rf_formula,
                     data = points_df_train,
                     probability = TRUE,
                     importance = 'impurity',
                     case.weights = c(points_df_train$n_negative,
                                      points_df_train$n_positive))
    
    pred_data <- as.data.frame(points_df[,layer_names])
    names(pred_data) <- layer_names
    
    # If fixing any covariates, specify here
    if(!is.null(fix_cov)){
      for(j in 1:length(fix_cov$cov_name)){
      pred_data[[fix_cov$cov_name[j]]] <- fix_cov$cov_val[j]
      }
    }

    fitted_predictions <- predict(rf_fit, pred_data)
    points$fitted_predictions <- fitted_predictions$predictions[,2]
    fitted_predictions_adj <- points$fitted_predictions 
    half_positive <- 0.5 / max(points$n_trials, na.rm=T)
    fitted_predictions_adj[fitted_predictions_adj==0] <- half_positive
    fitted_predictions_adj[fitted_predictions_adj==1] <- 1 - half_positive
    points$fitted_predictions_logit <- log(fitted_predictions_adj / (1-fitted_predictions_adj))
    
    points$cv_predictions <- NA
    points$cv_predictions[points_df_train$row_id[valid_indeces]] <- unlist(cv_predictions)
    cv_predictions_adj <- points$cv_predictions
    cv_predictions_adj[cv_predictions_adj==0] <- half_positive
    cv_predictions_adj[cv_predictions_adj==1] <- 1 - half_positive
    points$cv_predictions_logit <- log(cv_predictions_adj / (1-cv_predictions_adj))
  }

  if(model_type == "randomforest"){
    importance = data.frame(rf_fit$variable.importance)
  }else{
    importance = NULL
  }
  return(list(points = points,
              importance = importance))
}
