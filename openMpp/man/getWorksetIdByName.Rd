\name{getWorksetIdByName}
\alias{getWorksetIdByName}
\title{
Return working set id by name
}
\description{
Return working set id by name
}
\usage{
getWorksetIdByName(dbCon, defRs, worksetName)
}
\arguments{
  \item{dbCon}{
    database connection
  }
  \item{defRs}{
    model definition: database rows describing model input parameters and output tables
  }
  \item{worksetName}{
    name of parameters working set
  }
}
\details{
Return working set id by name. 
If model have no working set with that name then return is negative.
If model has multiple working sets with that name then return min(set id) with such name.
}
\value{
  Working set id: positive integer on success or negative if not found.
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
  \code{\link{getModel}}
  \code{\link{getDefaultWorksetId}}
  \code{\link{getWorksetRunIds}}
}
\examples{
  theDb <- dbConnect(RSQLite::SQLite(), "modelOne.sqlite", synchronous = "full")
  invisible(dbGetQuery(theDb, "PRAGMA busy_timeout = 86400")) # recommended

  # get model by name: use such call if you have only one version of the model
  defRs <- getModel(theDb, "modelOne")

  # get default working set id by name, it expected to be exist
  setId <- getWorksetIdByName(theDb, defRs, defRs$modelDic$model_name)
  
  # try to find "myData" working set id
  setId <- getWorksetIdByName(theDb, defRs, "myData")
  if (setId <= 0L) warning("workset not found: ", "myData")

  dbDisconnect(theDb)
}
\keyword{ OpenM++ }
\keyword{ database }
