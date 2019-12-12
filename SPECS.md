# fn-prevalence-predictor-mgcv

Give us a bunch of GeoJSON points with numbers examined and numbers positive, as well as a GeoJSON of prediction points, and we'll predict the probability of occurrence at each prediction point.

## Parameters

A nested JSON object containing:
- `point_data` - {GeoJSON FeatureCollection} Required. Features with following properties:
  - `n_trials` - {integer} Required. Number of individuals examined/tested at each location (‘null’ for points without observations)
  - `n_positive` - {integer} Required. Number of individuals positive at each location (‘null’ for points without observations)
  - `id` - {string} Optional id for each point. Must be unique. If not provided, 1:n (where n is the number of Features in the FeatureCollection) will be used.
  
- `exceedance_threshold` - {numeric} Optional. Defines the exceedance threshold used to calculate exceedance probabilities. Must be >0 and <1. 

- `layer_names` - {array of strings} Optional. Default is to run with only latitude and longitude. Names relating to the covariate to use to model and predict. See [here](https://github.com/disarm-platform/fn-covariate-extractor/blob/master/SPECS.md) for options.

- `batch_size` - {integer} Optional. The number of adaptively sampled locations to select.

- `uncertainty_fieldname` - {string} Required if 'batch_size' is specified. The field to use to conduct adaptive sampling. To identify optimal locations in order to increase precision of prevalence predictions, choose 'prevalence_bci_width'. To identify optimal locations in order to increase classification accuracy (where classes are defined using exceedance threshold) choose 'exceedance_uncertainty'. Defaults to `prevalence_bci_width`.


## Constraints

- maximum number of points/features
- maximum number of layers is XX
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