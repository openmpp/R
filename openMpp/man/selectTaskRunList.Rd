\name{selectTaskRunList}
\alias{selectTaskRunList}
\title{
Select list of modeling task runs
}
\description{
Select list of modeling task runs
}
\usage{
selectTaskRunList(dbCon, taskId)
}
\arguments{
  \item{dbCon}{
    database connection
  }
  \item{taskId}{
    id of modeling task
  }
}
\details{
This call return for specified task id list task run id's, status and time.

Task run status can be one of:
\itemize{
  \item \code{i} = not yet started
  \item \code{p} = run in progress
  \item \code{w} = run in progress, wait for additional input
  \item \code{s} = completed successfully
  \item \code{e} = failed (error)
  \item \code{x} = reserved
}
  
Status \code{w} means task can be dynamically updated by external script.
Model executable is waiting for additional input into or for "ready to be completed" signal.
Use \code{setTaskWaitCompleted} function to mark task as "ready to be completed".
Use \code{updateTask} function to insert additional task input.
}
\value{
  List of database rows:
  \item{taskLst}{ task_lst row: task id and name }
  \item{taskRunLst}{ task_run_lst rows: task run id, status and time }
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
  \code{\link{getTaskIdByName}}
  \code{\link{getTaskFirstRunId}}
  \code{\link{getTaskLastRunId}}
  \code{\link{selectTask}}
  \code{\link{selectTaskList}}
  \code{\link{selectTaskRun}}
  \code{\link{setTaskWaitCompleted}}
}
\examples{
  #
  # connect to database
  #
  theDb <- dbConnect(RSQLite::SQLite(), "modelOne.sqlite", synchronous = "full")
  invisible(dbGetQuery(theDb, "PRAGMA busy_timeout = 86400")) # recommended
  
  # get definition for "modelOne" model
  #
  # use model name only to identify the model
  # if there are multiple versions of the model in database 
  # then first one is selected: where model id = min(model_id) for "modelOne"
  #
  defRs <- getModel(theDb, "modelOne")
  
  taskId <- getTaskIdByName(theDb, defRs, "taskOne")
  if (taskId <= 0L) stop("task: ", "taskOne", " not found for model: ", defRs$modelDic$model_name, " ", defRs$modelDic$model_digest)
  
  # last (most recent) run of that task
  lastId <- getTaskLastRunId(theDb, taskId)
  if (lastId <= 0L) stop("task run(s) not found, task: ", taskId)
  
  # select task run status, input and output
  taskRunRs <- selectTaskRun(theDb, lastId)
  
  # select list of all task runs
  taskRunLstRs <- selectTaskRunList(theDb, taskId)
  
  dbDisconnect(theDb)
}
\keyword{ OpenM++ }
\keyword{ database }
