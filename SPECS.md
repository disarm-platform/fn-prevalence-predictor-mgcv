# fn-prevalence-predictor-mgcv

Give us a bunch of GeoJSON points with numbers examined and numbers positive, as well as a GeoJSON of prediction points, and we'll predict the probability of occurrence at each prediction point as well as the uncertainty and exceedance probability (probability that prevalence is greater than a threshold). Fits a geoadditive model using `mgcv` package and uses cross-validated predictions from a random forest using ecological/environmental variables as a covariate. The function also allows users to obtain the locations of surther sites to survey in order to minimize hotspot classification error. 

See [here](https://www.medrxiv.org/content/10.1101/2020.01.10.20016964v1) for an explanation of the method which is similar except here `mgcv` (geoadditive model) is used to fit the spatial model instead of `spaMM` (geostatistical model). This is done to increase computational speed.

## Parameters

A nested JSON object containing:
- `point_data` - {GeoJSON FeatureCollection} Required. Features with following properties:
  - `n_trials` - {integer} Required. Number of individuals examined/tested at each location (‘null’ for points without observations)
  - `n_positive` - {integer} Required. Number of individuals positive at each location (‘null’ for points without observations)
  - `id` - {string} Optional id for each point. Must be unique. If not provided, 1:n (where n is the number of Features in the FeatureCollection) will be used.
  
- `exceedance_threshold` - {numeric} Required. Defines the exceedance threshold used to calculate exceedance probabilities. Must be >0 and <1. 

- `layer_names` - {array of strings} Optional. Default is to run with only latitude and longitude. Names relating to the covariate to use to model and predict. See [here](https://github.com/disarm-platform/fn-covariate-extractor/blob/master/SPECS.md) for options.

- `additional_covariates` - {array of strings} Optional vector of column names of `point_data` referencing additional covariates to include in the model. Defulats to NULL.

-  `covariate_extractor_url` - {string} Optional. The function currently makes use of the temporary DiSARM API function `fn-covariate-extractor` to extract values of `layer_names` at locations specified in `point_data`. If this algorithm is hostedsomewhere other than the DiSARM API, specify the URL here. 

- `batch_size` - {integer} Optional. The number of adaptively sampled locations to select.

- `uncertainty_fieldname` - {string} Required if 'batch_size' is specified. The field to use to conduct adaptive sampling. To identify optimal locations in order to increase precision of prevalence predictions, choose 'prevalence_bci_width'. To identify optimal locations in order to increase classification accuracy (where classes are defined using exceedance threshold) choose 'exceedance_uncertainty'. Defaults to `prevalence_bci_width`.

- `seed` - {integer} Optional. The random seed to use. Defaults to 1.

- `v` - {integer} Optional. Number of folds to use for the machine learning cross-validation step. Defaults to 10. 

## Constraints

- maximum number of points/features (being established)
- maximum number of layers is currently unknown but likely to be fine up to 25 covariates.
- can only include points within a single country

## Response

`point_data` {GeoJSON FeatureCollection} with the following fields: 
- `id` - as defined by user or 1:n (where n is the number of Features in the FeatureCollection)
- `prevalence_prediction` - best-guess (probability of occurrence (0-1 scale))
- `prevalence_bci_width` - difference between upper 97.5% and lower 2.25% quantiles
- `exceedance_probability` - Only exists if `exceedance_threshold` provided
- `exceedance_uncertainty` - Only exists if `exceedance_threshold` provided
- `entropy` - Only exists if `exceedance_threshold` provided. Calculated as -p * log(p) - (1-p) * log (1-p) where p is `exceedance_probability`
- `adaptively_selected` - Boolean corresponding to whether location was selected using the adaptive sampling algorithm. Only exists if `batch_size` specified. 