#' @title Define the information required for classifying time series
#' @name .sits_class_info
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description Time series classification requires that users do a series of steps:
#' (a) Provide labelled samples that will be used as training data.
#' (b) Provide information on how the classification will be performed, including data timeline,
#' temporal interval, and start and end dates per interval.
#' (c) Clean the training data to ensure it meets the specifications of the classification info.
#' (d) Use the clean data to train a machine learning classifier.
#' (e) Classify non-labelled data sets.
#'
#' In this set of steps, this function provides support for step (b). It requires the user
#' to provide a timeline, the classification interval, and the start and end dates of
#' the reference period. The results is a tibble with information that allows the user
#' to perform steps (c) to (e).
#'
#' @param  data.tb         Description on the data being classified.
#' @param  samples.tb      Samples used for training the classification model.
#' @param  interval        Interval between two sucessive classifications.
#' @return A tibble with the classification information.
.sits_class_info <- function(data.tb, samples.tb, interval){
    # find the timeline
    timeline <- .sits_timeline(data.tb)

    # find the labels
    labels <- sits_labels(samples.tb)$label
    # find the bands
    bands <- sits_bands(samples.tb)

    # what is the reference start date?
    ref_start_date <- lubridate::as_date(samples.tb[1,]$start_date)
    # what is the reference end date?
    ref_end_date <- lubridate::as_date(samples.tb[1,]$end_date)

    # obtain the reference dates that match the patterns in the full timeline
    ref_dates.lst <- sits_match_timeline(timeline, ref_start_date, ref_end_date, interval)

    # obtain the indexes of the timeline that match the reference dates
    dates_index.lst <- .sits_match_indexes(timeline, ref_dates.lst)

    # find the number of the samples
    nsamples <- dates_index.lst[[1]][2] - dates_index.lst[[1]][1] + 1

    class_info.tb <- tibble::tibble(
        bands          = list(bands),
        labels         = list(labels),
        interval       = interval,
        timeline       = list(timeline),
        num_samples    = nsamples,
        ref_dates      = list(ref_dates.lst),
        dates_index    = list(dates_index.lst)
    )
    return(class_info.tb)
}

#' @title Find the time index of the blocks to be extracted for classification
#' @name .sits_get_time_index
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description Obtains the indexes of the blocks to be extract for each time interval
#' associated with classification.
#'
#' @param class_info.tb Tibble with information required for classification.
#' @return List with indexes of the input data set associated to each time interval
#' used for classification.
.sits_get_time_index <- function(class_info.tb) {
    # find the subsets of the input data
    dates_index.lst <- class_info.tb$dates_index[[1]]

    #retrieve the timeline of the data
    timeline <- class_info.tb$timeline[[1]]

    # retrieve the bands
    bands <- class_info.tb$bands[[1]]

    #retrieve the time index
    time_index.lst  <- .sits_time_index(dates_index.lst, timeline, bands)

    return(time_index.lst)
}

#' @title Test if starting date fits with the timeline
#' @name .sits_is_valid_start_date
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description A timeline is a list of dates where observations are available. This
#' functions estimates if a date is valid by comparing it to the timeline. If the date's estimate
#' is not inside the timeline and the difference between the date and the first date of timeline is
#' greater than the acquisition interval of the timeline, then we conclude the date is not valid.
#'
#' @param date        A date.
#' @param timeline    A vector of reference dates.
#' @return Is this is valid starting date?
.sits_is_valid_start_date <- function(date, timeline){
    # is the date inside the timeline?
    if (date %within% lubridate::interval(timeline[1], timeline[length(timeline)])) return(TRUE)
    # what is the difference in days between the last two days of the timeline?
    timeline_diff <- as.integer(timeline[2] - timeline[1])
    # if the difference in days in the timeline is smaller than the difference
    # between the reference date and the first date of the timeline, then
    # we assume the date is valid
    if (abs(as.integer(date - timeline[1]))  <= timeline_diff ) return(TRUE)

    return(FALSE)
}

#' @title Test if end date fits inside the timeline
#' @name .sits_is_valid_end_date
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description A timeline is a list of dates where observations are available. This
#' functions estimates if a date is valid by comparing it to the timeline. If the date's estimate
#' is not inside the timeline and the difference between the date and the last date of timeline is
#' greater than the acquisition interval of the timeline, then we conclude the date is not valid.
#'
#' @param date        A Date.
#' @param timeline    A vector of reference dates.
#' @return Nearest date.
.sits_is_valid_end_date <- function(date, timeline){
    # is the date inside the timeline?

    if (date %within% lubridate::interval(timeline[1], timeline[length(timeline)])) return(TRUE)
    # what is the difference in days between the last two days of the timeline?
    timeline_diff <- as.integer(timeline[length(timeline)] - timeline[length(timeline) - 1])
    # if the difference in days in the timeline is smaller than the difference
    # between the reference date and the last date of the timeline, then
    # we assume the date is valid
    if (abs(as.integer(date - timeline[length(timeline)]))  <= timeline_diff) return(TRUE)

    return(FALSE)
}

#' @title Find dates in the input coverage that match those of the patterns
#' @name sits_match_timeline
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description For correct classification, the time series of the input data set
#'              should be aligned to that of the reference data set (usually a set of patterns).
#'              This function aligns these data sets so that shape matching works correctly
#'
#' @param timeline              Timeline of input observations (vector).
#' @param ref_start_date        The day of the year to be taken as reference for starting the classification.
#' @param ref_end_date          The day of the year to be taken as reference for end the classification.
#' @param interval              Period between two classification.
#' @return A list of breaks that will be applied to the input data set.
#' @examples
#' # get a timeline for MODIS data
#' data("timeline_2000_2017")
#' # get a set of subsets for a period of 10 years
#' ref_start_date <- lubridate::ymd("2000-08-28")
#' ref_end_date <- lubridate::ymd("2000-08-13")
#' subset_dates.lst <- sits_match_timeline (timeline_2000_2017, ref_start_date, ref_end_date)
#' @export
sits_match_timeline <- function(timeline, ref_start_date, ref_end_date, interval = "12 month"){
    # make sure the timelines is a valid set of dates
    timeline <- lubridate::as_date(timeline)

    #define the input start and end dates
    input_start_date <- timeline[1]
    input_end_date   <- timeline[length(timeline)]

    # how many samples are there per interval?
    num_samples <- .sits_num_samples(timeline, interval)

    # what is the expected start and end dates based on the patterns?
    ref_st_mday  <- as.character(lubridate::mday(ref_start_date))
    ref_st_month <- as.character(lubridate::month(ref_start_date))
    year_st_date  <- as.character(lubridate::year(input_start_date))
    est_start_date    <- lubridate::as_date(paste0(year_st_date,"-",ref_st_month,"-",ref_st_mday))
    # find the actual starting date by searching the timeline
    start_date <- timeline[which.min(abs(est_start_date - timeline))]

    # is the start date a valid one?
    ensurer::ensure_that(start_date, .sits_is_valid_start_date(., timeline),
                         err_desc = "sits_match_timelines: expected start date in not inside timeline of observations")

    # obtain the subset dates to break the input data set
    # adjust the dates to match the timeline
    subset_dates.lst <- list()

    # what is the expected end date of the classification?

    end_date <- timeline[which(timeline == start_date) + (num_samples - 1)]

    # is the start date a valid one?
    ensurer::ensure_that(end_date, !(is.na(end_date)),
                         err_desc = "sits_match_timelines: start and end date of samples do not match timeline /n
                                     Please compare your timeline with your samples")

    # go through the timeline of the data and find the reference dates for the classification
    while (!is.na(end_date)) {
        # add the start and end date
        subset_dates.lst[[length(subset_dates.lst) + 1 ]] <- c(start_date, end_date)

        # estimate the next end date based on the interval
        next_start_date <- as.Date(start_date + lubridate::as.duration(interval))
        # define the estimated end date of the input data based on the patterns

        # find the actual start date by searching the timeline
        start_date <- timeline[which.min(abs(next_start_date - timeline))]
        # estimate
        end_date <- timeline[which(timeline == start_date) + (num_samples - 1)]
    }
    # is the end date a valid one?
    end_date   <- subset_dates.lst[[length(subset_dates.lst)]][2]
    ensurer::ensure_that(end_date, .sits_is_valid_end_date(., timeline),
                         err_desc = "sits_match_timelines: expected end date in not inside timeline of observations")

    return(subset_dates.lst)
}

#' @title Find indexes in a timeline that match the reference dates
#' @name .sits_match_indexes
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description For correct classification, the time series of the input data set
#'              should be aligned to that of the reference data set (usually a set of patterns).
#'              This function aligns these data sets so that shape matching works correctly
#'
#' @param timeline              Timeline of input observations (vector).
#' @param ref_dates.lst         A list of breaks that will be applied to the input data set.
#' @return A list of indexes that match the reference dates to the timelines.
.sits_match_indexes <- function(timeline, ref_dates.lst){
    dates_index.lst <- ref_dates.lst %>%
        purrr::map(function(date_pair) {
            start_index <- which(timeline == date_pair[1])
            end_index   <- which(timeline == date_pair[2])

            dates_index <- c(start_index, end_index)
            return(dates_index)
        })

    return(dates_index.lst)
}

#' @title Find number of samples, given a timeline and an interval
#' @name .sits_num_samples
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description This function retrieves the number of samples
#'
#' @param timeline              Timeline of input observations (vector).
#' @param interval              Period to match the data to the patterns.
#' @return The number of measures during the chosen interval.
.sits_num_samples <- function(timeline, interval = "12 month"){
    start_date <- timeline[1]
    next_interval_date <- lubridate::as_date(lubridate::as_date(start_date) + lubridate::as.duration(interval))

    times <- timeline[(next_interval_date - timeline) >  0]
    end_date <- timeline[which.max(times)]

    return(which(timeline == end_date) - which(timeline == start_date) + 1)
}

#' @title Provide a list of indexes to extract data from a distance table for classification
#' @name .sits_select_indexes
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description Given a list of time indexes that indicate the start and end of the values to
#' be extracted to classify each band, obtain a list of indexes that will be used to
#' extract values from a combined distance tibble (with has all the bands put together).
#'
#' @param  class_info.tb      Tibble with classification information.
#' @param  ntimes             Number of time instances.
#' @return List of values to be extracted for each classification interval.
.sits_select_indexes <- function(class_info.tb, ntimes) {
    # find the subsets of the input data
    dates_index.lst <- class_info.tb$dates_index[[1]]

    # find the number of the samples
    nsamples <- class_info.tb$num_samples

    #retrieve the timeline of the data
    timeline <- class_info.tb$timeline[[1]]

    # retrieve the bands
    bands <- class_info.tb$bands[[1]]
    nbands <- length(bands)

    #retrieve the time index
    time_index.lst  <- .sits_time_index(dates_index.lst, timeline, bands)

    select.lst <- vector("list", length(time_index.lst))

    size_lst = nbands*ntimes + 2

    for (t in 1:length(time_index.lst)) {
        idx <- time_index.lst[[t]]
        # for a given time index, build the data.table to be classified
        # build the classification matrix extracting the relevant columns
        select.lst[[t]] <- logical(length = size_lst)
        select.lst[[t]][1:2] <- TRUE
        for (b in 1:nbands) {
            i1 <- idx[(2*b - 1)] + 2
            i2 <- idx[2*b] + 2
            select.lst[[t]][i1:i2] <- TRUE
        }
    }
    return(select.lst)
}

#' @title Provide a list of indexes to extract data from a raster-derived data table for classification
#' @name .sits_select_raster_indexes
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description Given a list of time indexes that indicate the start and end of the values to
#' be extracted to classify each band, obtain a list of indexes that will be used to
#' extract values from a combined distance tibble (with has all the bands put together)
#'
#' @param  coverage           Coverage with input data set.
#' @param  samples            Tibble with samples used for classification.
#' @param  interval           Classification interval.
#' @return List of values to be extracted for each classification interval.
.sits_select_raster_indexes <- function(coverage, samples, interval) {
    # define the classification info parameters
    class_info <- .sits_class_info(coverage, samples, interval)

    # define the time indexes required for classification
    time_index.lst <- .sits_get_time_index(class_info)

    # create a vector with selection interval
    select.lst <- vector("list", length(time_index.lst))

    # find the length of the timeline
    ntimes <- length(coverage$timeline[[1]][[1]])

    # get the bands in the same order as the samples
    nbands <- length(sits_bands(samples))

    size_lst = nbands*ntimes + 2

    for (t in 1:length(time_index.lst)) {
        idx <- time_index.lst[[t]]
        # for a given time index, build the data.table to be classified
        # build the classification matrix extracting the relevant columns
        select.lst[[t]] <- logical(length = size_lst)
        select.lst[[t]][1:2] <- TRUE
        for (b in 1:nbands) {
            i1 <- idx[(2*b - 1)] + 2
            i2 <- idx[2*b] + 2
            select.lst[[t]][i1:i2] <- TRUE
        }
    }
    return(select.lst)
}

#' @title Create a list of time indexes from the dates index
#' @name  .sits_time_index
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @param  dates_index.lst  A list of dates with the subsets of the input data.
#' @param  timeline         The timeline of the data set.
#' @param  bands            Bands used for classification.
#' @return The subsets of the timeline.
.sits_time_index <- function(dates_index.lst, timeline, bands) {
    # transform the dates index (a list of dates) to a list of indexes
    # this speeds up extracting the distances for classification
    time_index.lst <- dates_index.lst %>%
        purrr::map(function(idx){
            index_ts <- vector()
            for (i in 1:length(bands)) {
                idx1 <- idx[1] + (i - 1)*length(timeline)
                index_ts[length(index_ts) + 1 ] <- idx1
                idx2 <- idx[2] + (i - 1)*length(timeline)
                index_ts[length(index_ts) + 1 ] <- idx2
            }
            return(index_ts)
        })
    return(time_index.lst)
}

#' @title Obtains the timeline for a coverage
#' @name .sits_timeline
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description This function returns the timeline for a given coverage.
#'
#' @param  data.tb  A sits tibble (either a sits tibble or a raster metadata).
.sits_timeline <- function(data.tb){
    timeline <-  NULL
    # is this a coverage metadata?
    if ("timeline" %in% names(data.tb))
        timeline <- as.Date(data.tb[1,]$timeline[[1]][[1]])

    # is this a sits tibble with the time series?
    if ("time_series" %in% names(data.tb))
        timeline <- lubridate::as_date(data.tb[1,]$time_series[[1]]$Index)

    ensurer::ensure_that(timeline, !purrr::is_null(.), err_desc = "sits_timeline: input does not contain a valid timeline")

    return(timeline)
}
