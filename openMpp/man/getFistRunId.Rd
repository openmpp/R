\name{getFirstRunId}
\alias{getFirstRunId}
\title{
Return id of first model run results
}
\description{
Return id of first model run results
}
\usage{
getFirstRunId(dbCon, defRs)
}
\arguments{
  \item{dbCon}{
    database connection
  }
  \item{defRs}{
    model definition: database rows describing model input parameters and output tables
  }
}
\details{
Return id of first model run results id, it is positive integer.
If model does not have any run results (model never executed) then return negative value.
}
\value{
  Run id: positive integer on success or negative on if not found.
}
\references{
OpenM++ documentation: https://github.com/openmpp/openmpp.github.io/wiki
}
\author{
amc1999
}
\note{
To run examples you must have modelOne database modelOne.sqlite in current directory
}

\seealso{
  \code{\link{getLastRunId}}
  \code{\link{getModel}}
  \code{\link{getTaskIdByName}}
}
\examples{
  theDb <- dbConnect(RSQLite::SQLite(), "modelOne.sqlite", synchronous = "full")
  invisible(dbGetQuery(theDb, "PRAGMA busy_timeout = 86400")) # recommended

  # get model by name: use such call if you have only one version of the model
  defRs <- getModel(theDb, "modelOne")

  # get first run id of that model
  runId <- getFirstRunId(theDb, defRs)
  if (runId <= 0L) warning("model run results not found")

  dbDisconnect(theDb)
}
\keyword{ OpenM++ }
\keyword{ database }
