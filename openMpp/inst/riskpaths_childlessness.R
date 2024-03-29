# use openMpp library for openM++ database access
library(DBI)
library("openMpp")
library("RSQLite")

#
# Using RiskPaths model 
#   to analyze contribution of delayed union formations 
#   versus decreased fertility on childlessness
#
# Input parameters:
#   AgeBaselineForm1: age baseline for first union formation
#   UnionStatusPreg1: relative risks of union status on first pregnancy
# Output value:
#   T05_CohortFertility: Cohort fertility, expression 1
#

##################################################################
# To run this example please uncomment and/or change values below
# to match your hardware and file system environment:
#
# model_exe    <- path to the model executable, i.e.: "./RiskPaths" or "RiskPaths.exe"
# model_sqlite <- path to the model.sqlite database:  "RiskPaths.sqlite"
# model_args   <- optional arguments to control model run, for example:
#       -OpenM.SubValues 8 <- number of simation members
#       -OpenM.Threads 4   <- number of computatinal threads
#
### For running on a local machine using the working directory in R 
#
# For the following values to work, you must first set the R Working directory
# to the directory containing the RiskPaths executable and the SQLite database.
# In RStudio Session > Set Working Directory > Choose Directory, 
# then navigate to location, e.g.: /OM_ROOT/models/RiskPaths/ompp/bin
# Alternatively, one may use setwd(), e.g.: setwd("/OM_ROOT/models/RiskPaths/ompp/bin")
#
model_exe = "./RiskPaths"
model_sqlite = "RiskPaths.sqlite"
model_args = " "  # default: 1 simulation member and 1 thread
# model_args = " -OpenM.SubValues 8 -OpenM.Threads 4" 
#
### For running on a local machine using explicit paths
#
# model_exe = "/path/to/executable/model/RiskPaths"
# model_sqlite = "/path/to/SQLite/database/RiskPaths.sqlite"
#
### For running on cluster (change to match your cluster)
#
# model_exe = "mpiexec"
# model_sqlite = "/mirror/RiskPaths.sqlite"
# model_args = "-n 8 /mirror/RiskPaths -OpenM.SubValues 16 -OpenM.Threads 2"
##################################################################

# 
# connect to database to model databes
#
theDb <- dbConnect(RSQLite::SQLite(), model_sqlite, synchronous = "full")
invisible(dbGetQuery(theDb, "PRAGMA busy_timeout = 86400"))   # recommended

# find RiskPaths model in database and get model dictionaries ("modelDic", "typeDic", etc...)
defRs <- getModel(theDb, "RiskPaths")

#
# create a copy of default model parameters
#
baseRunId <- getFirstRunId(theDb, defRs)
if (baseRunId <= 0) 
  stop("no run results found for the model ", defRs$modelDic$model_name, " ", defRs$modelDic$model_digest)

#
# get default values for AgeBaselineForm1 and UnionStatusPreg1 parameters 
# by reading it from first model run results
# assuming first run of the model done with default set of parameters
#
ageFirstUnionRs   <- selectRunParameter(theDb, defRs, baseRunId, "AgeBaselineForm1")
unionStatusPregRs <- selectRunParameter(theDb, defRs, baseRunId, "UnionStatusPreg1")

#
# create modeling task with
# all input parameters same as model default except of
# AgeBaselineForm1, UnionStatusPreg1 and SimulationCases parameters
#
casesParam <- list(name = "SimulationCases", value = 1000L) # number of simulation cases

taskTxt <- data.frame(      # name (auto generated), description and notes for the task
  name  = NA,
  lang  = "EN",
  descr = "Analyzing childlessness",
  note  = NA,
  stringsAsFactors = FALSE
)

taskId <- createTask(theDb, defRs, taskTxt)
if (taskId <= 0L) stop("task creation failed: ", defRs$modelDic$model_name, " ", defRs$modelDic$model_digest)

# parameters scale
#
# scaleValues <- seq(from = 0.50, to = 1.00, by = 0.50) # tiny set of runs for quick test
#
scaleValues <- seq(from = 0.44, to = 1.00, by = 0.02)

UnionStatusMultipler = rep(1, length(unionStatusPregRs$param_value)) # vector of 1's

for (scAgeBy in scaleValues)
{
  print(c("Scale age: ", scAgeBy))
  
  for (scUnionBy in scaleValues)
  {
    ageParam <- list(name = "AgeBaselineForm1", value = ageFirstUnionRs$param_value * scAgeBy)
    
    UnionStatusMultipler[1:2] = scUnionBy  # scale first two values of parameter vector
    unionParam <- list(name = "UnionStatusPreg1", value = unionStatusPregRs$param_value *  UnionStatusMultipler )

    # Append new working set of parameters into the task. A corresponding setId is generated.
    setId <- createWorksetBasedOnRun(theDb, defRs, baseRunId, NA, ageParam, unionParam, casesParam)
    setReadonlyWorkset(theDb, defRs, TRUE, setId)
    
    taskId <- updateTask(theDb, defRs, taskId, setIds = setId)
  }
}

#
# run the model on cluster or local desktop
# consult your cluster admin on how to use computational grid
print(paste("Run the model:", model_exe, "...please wait..."))

system2(
  model_exe, 
  paste(
    model_args,
    " -OpenM.TaskId ", taskId, 
    " -OpenM.LogToConsole false",
    " -OpenM.LogToFile true",
    " -OpenM.ProgressPercent 100",
    sep = ""
  )
)

#
# read results of task run from database
#   cohort fertility: T05_CohortFertility.Expr1
#
taskRunId <- getTaskLastRunId(theDb, taskId)  # most recent task run id
taskRunRs <- selectTaskRun(theDb, taskRunId)  # get result id's
#
# taskRunId
# [1] 111
# taskRunRs$taskRunSet  # Content for "tiny set of runs"
#   task_run_id run_id set_id task_id
# 1         108    109    104     103
# 2         108    110    105     103
# 3         108    111    106     103
# 4         108    112    107     103
# Main scenario task_id 103 comes with 4 sets of parameters  set_id 104, 105, 106, 107  (e.g. PSA)
# The main scenario/task was run (task_run_id 108) which spins out 4 runs run_id 109, 110, 111, 112

scaleLen <- length(scaleValues)
childlessnessMat <- matrix(data = NA, nrow = scaleLen, ncol = scaleLen, byrow = TRUE)

runPos <- 1
for (k in 1:scaleLen)
{
  for (j in 1:scaleLen)
  {
    # cohort fertility: T05_CohortFertility.Expr1
    expr1Rs <- selectRunOutputValue(theDb, defRs, taskRunRs$taskRunSet$run_id[runPos], "T05_CohortFertility", "Expr1")
    childlessnessMat[k, j] = expr1Rs$expr_value
    runPos <- runPos + 1
  }
}

dbDisconnect(theDb)   # close database connection

#
# display the results
#
persp(
  x = scaleValues,
  y = scaleValues,
  z = childlessnessMat,
  xlab = "Decreased union formation",
  ylab = "Decreased fertility", 
  zlab = "Childlessness", 
  theta = 30, phi = 30, expand = 0.5, ticktype = "detailed",
  col = "lightgreen",
  cex.axis = 0.7
)
