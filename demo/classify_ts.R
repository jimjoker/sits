# satellite image time series package (SITS)
# example of the classification of a time series
#devtools::install_github("gilbertocamara/sits")
library(sits)

# In this example, we are going to train a ML model and then will classify a point retrieved
# from the WTSS server and then a set of samples retrieved from the server
# we will show how to set the classification info

# Retrieve the set of samples for the Mato Grosso region (provided by EMBRAPA)
data(samples_mt_9classes)

# print the bands available
sits_bands(samples_mt_9classes)

# select the bands "ndvi", "evi", "nir", and "mir"
samples.tb <- sits_select_bands(samples_mt_9classes, ndvi, evi, nir, mir)

#select a random forest model
rfor_model <- sits_train(samples.tb, ml_method = sits_rfor())

# Retrieve a time series
data(point_mt_6bands)

# select the bands "ndvi", "evi", "nir", and "mir"
point.tb <- sits_select_bands(point_mt_6bands, ndvi, evi, nir, mir)

# classify the point
class.tb <- sits_classify(point.tb, rfor_model)

# plot the classification
sits_plot(class.tb)

