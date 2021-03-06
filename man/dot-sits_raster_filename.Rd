% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_coverage.R
\name{.sits_raster_filename}
\alias{.sits_raster_filename}
\title{Define a filename associated to one classified raster layer}
\usage{
.sits_raster_filename(file, start_date, end_date)
}
\arguments{
\item{file}{Original file name (without temporal information).}

\item{start_date}{Starting date of the time series classification.}

\item{end_date}{End date of the time series classification.}
}
\value{
Name of the classification file for the required interval.
}
\description{
Creates a filename for a raster layer with associated temporal information,
                given a basic filename.
}
\author{
Gilberto Camara, \email{gilberto.camara@inpe.br}
}
