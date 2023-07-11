#
# R integration example using RiskPaths model
#   to analyze contribution of delayed union formations
#   versus decreased fertility on childlessness
#
# Prerequisite:
#
# download openM++ release from https://github.com/openmpp/main/releases/latest
# unpack it into any directory
# start oms web-service:
#   Windows:
#     cd C:\my-openmpp-release
#     bin\ompp_ui.bat
#   Linux:
#     cd ~/my-openmpp-release
#     bin/oms
#
# Script below is using openM++ web-service "oms"
# to run the model, modify parameters and read output values.
#

# If jsonlite or httr is not installed then do:
#   install.packages("jsonlite")
#   install.packages("httr")
#
library("jsonlite")
library("httr")

# Include openM++ helper functions from your $HOME directory
# on Windows HOME directory is: "C:\Users\User Name Here\Documents"
#
# if you don't have omsCommon.R then download it from https://github.com/openmpp/R/oms-R
# if you have omsCommon.R in some other location then update path below
#
source("~/omsCommon.R")

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

# Model name: RiskPaths
#
# If you have multiple versions of the model with the same name
# then instead of:
#   ModelName = "RiskPaths"
# use model digest to identify specific model version, for example:
#   ModelDigest = "d90e1e9a49a06d972ecf1d50e684c62b"
#
md <- "RiskPaths"

# oms web-service URL, it can be hard-coded, for example: "http://localhost:4040/api/"
#
apiUrl <- getOmsApiUrl()

# Find first model run to use it as our base run
#
# Parameters AgeBaselineForm1 and UnionStatusPreg1 are varied by this script
# and the rest of parameters we are getting from base model run
#
rsp <- GET(paste0(
    apiUrl, "model/", md, "/run/status/first"
  ))
if (http_type(rsp) != 'application/json') {
  stop("Failed to get first run status")
}
jr <- content(rsp)
firstRunDigest <- jr$RunDigest

# get initial values for AgeBaselineForm1 and UnionStatusPreg1 parameters
# by reading it from first model run results
#
rsp <- GET(paste0(
    apiUrl, "model/", md, "/run/", firstRunDigest, "/parameter/AgeBaselineForm1/value/start/0/count/0"
  ))
if (http_type(rsp) != 'application/json') {
  stop("Failed to get parameter AgeBaselineForm1")
}
ageFirstUnion <- content(rsp)

rsp <- GET(paste0(
    apiUrl, "model/", md, "/run/", firstRunDigest, "/parameter/UnionStatusPreg1/value/start/0/count/0"
  ))
if (http_type(rsp) != 'application/json') {
  stop("Failed to get parameter UnionStatusPreg1")
}
unionStatusPreg <- content(rsp)

# Create multiple input scenarios and save all of it as our modelling task:
#   apply scale in range from 0.44 to 1.0
#   to AgeBaselineForm1 and UnionStatusPreg1 parameters
#
# scaleStep <- 0.08 # do 64 model runs
# scaleStep <- 0.5  # use this for quick test
#
scaleStep <- 0.08
scaleValues <- seq(from = 0.44, to = 1.00, by = scaleStep)

nameLst <- c()  # input scenario names, automatically generated

for (scaleAgeBy in scaleValues)
{
  print(c("Scale age: ", scaleAgeBy))

  ag <- ageFirstUnion
  for (k in 1:length(ag))
  {
    ag[[k]]$Value <- ageFirstUnion[[k]]$Value * scaleAgeBy
  }

  for (scaleUnionBy in scaleValues)
  {
    un <- unionStatusPreg
    un[[1]]$Value <- un[[1]]$Value * scaleUnionBy  # change only first two values
    un[[2]]$Value <- un[[2]]$Value * scaleUnionBy  # of UnionStatusPreg1 parameter

    # create new input scenario
    # automatically generate unique names for each input scenario
    #
    pd <- list(
        ModelName = md,
        Name = "",
        BaseRunDigest = firstRunDigest,
        IsReadonly = TRUE,
        Txt = list(
          list(LangCode = "EN", Descr = paste("Scale age:", scaleAgeBy, ", union status", scaleUnionBy)),
          list(LangCode = "FR", Descr = paste("Échelle d'âge:", scaleAgeBy, ", statut syndical", scaleUnionBy))
        ),
        Param = list(
          list(
            Name = "AgeBaselineForm1",
            SubCount = 1,
            Value = ag,
            Txt = list(
              list(LangCode = "FR", Note = paste("Mettre à l'échelle l'âge par:", scaleAgeBy))
            )
          ),
          list(
            Name = "UnionStatusPreg1",
            SubCount = 1,
            Value = un,
            Txt = list(
              list(LangCode = "EN", Note = paste("Scale union status by:", scaleAgeBy))
            )
          )
        )
      )
    jv <- toJSON(pd, pretty = TRUE, auto_unbox = TRUE)

    # create input scenario by submitting request to oms web-service
    rsp <- PUT(paste0(
          apiUrl, "workset-create"
        ),
        body = jv,
        content_type_json()
      )
    if (http_type(rsp) != 'application/json') {
      stop("Failed to create input set")
    }
    jr <- content(rsp)
    sn <- jr$Name  # name of new input scenario generated by oms web-service

    if (is.na(sn) || sn == "") stop("Fail to create input set, scales:", scaleAgeBy, scaleUnionBy)

    nameLst <- c(nameLst, sn)
  }
}

# Create modeling task from all input sets
# automatically generate unique name for the task
#
inpLen <- length(nameLst)

print(paste("Create task from", inpLen, "input scenarios"))

pd <- list(
    ModelName = md,
    Name = "",
    Set = nameLst,
    Txt = list(
      list(
        LangCode = "EN",
        Descr = paste("Task to run RiskPaths", inpLen, "times"),
        Note = paste("Task scales AgeBaselineForm1 and UnionStatusPreg1 parameters from 0.44 to 1.00 with step", scaleStep)
      )
    )
  )
jv <- toJSON(pd, pretty = TRUE, auto_unbox = TRUE)


# create task by submitting request to oms web-service
rsp <- PUT(paste0(
      apiUrl, "task-new"
    ),
    body = jv,
    content_type_json()
  )
if (http_type(rsp) != 'application/json') {
  stop("Failed to create modeling task")
}
jr <- content(rsp)
taskName <- jr$Name  # name of new task generated by oms web-service

if (is.na(taskName) || taskName == "") stop("Fail to create modeling task")

#
# Run RiskPaths with modeling task and wait until task is completed
#
# It is MPI model on small computational cluster of 4 servers,
# running 5 RiskPaths_mpi instancces: "root" leader process and 4 computational processes
# each computational process using modelling 4 threads
# root process does only database operations and coordinate child workoload.
#
print(paste("Starting modeling task:", taskName))

# use explicit model run stamp to avoid compatibility issues between cloud model run queue and desktop MPI
stamp <- sub('.' , '_', fixed = TRUE, format(Sys.time(),"%Y_%m_%d_%H_%M_%OS3"))

# prepare model run options
pd <- list(
    ModelDigest = md,
    Mpi = list(
      Np = 5,               # MPI cluster: run 5 processes: 4 for model and rott process
      IsNotOnRoot = TRUE    # MPI cluster: do not use root process for modelling
    ),
    Template = "mpi.RiskPaths.template.txt",  # MPI cluster: model run tempate
    Opts = list(
      OpenM.TaskName = taskName,
      OpenM.RunStamp = stamp,                # use explicit run stamp
      Parameter.SimulationCases = "1024",    # use 1024 simulation cases to get quick results
      OpenM.BaseRunDigest = firstRunDigest,  # base run to get the rest of input parameters
      OpenM.SubValues = "16",                # use 16 sub-values (sub-samples)
      OpenM.Threads = "4",                   # use 4 modeling threads
      OpenM.ProgressPercent = "100"          # reduce amount of progress messages in the log file
    )
  )
jv <- toJSON(pd, pretty = TRUE, auto_unbox = TRUE)

# run modeling task
rsp <- POST(paste0(
      apiUrl, "run"
    ),
    body = jv,
    content_type_json()
  )
if (http_type(rsp) != 'application/json') {
  stop("Failed to run the model")
}
jr <- content(rsp)

submitStamp <- jr$SubmitStamp # model run submission stamp: not empty if model run submitted to run queue
runStamp <- jr$RunStamp       # model run stamp: by default empty until model run not started

# wait until task completed
runDigests <- waitForTaskCompleted(taskName, stamp, apiUrl, md)

#
# get results of task run, cohort fertility: T05_CohortFertility.Expr1
#
pd <- list(
    Name = "T05_CohortFertility",
    ValueName = "Expr1",
    Size = 0             # read all rows of T05_CohortFertility.Expr1
  )
jv <- toJSON(pd, pretty = TRUE, auto_unbox = TRUE)

scaleLen <- length(scaleValues)
childlessnessMat <- matrix(data = NA, nrow = scaleLen, ncol = scaleLen, byrow = TRUE)

runIdx <- 1
for (k in 1:scaleLen)
{
  for (j in 1:scaleLen)
  {
    # for each run digest get T05_CohortFertility.Expr1 value
    #
    rsp <- POST(paste0(
            apiUrl, "model/", md, "/run/", runDigests[runIdx], "/table/value"
        ),
        body = jv,
        content_type_json()
      )
    if (http_type(rsp) != 'application/json') {
      stop("Failed to get T05_CohortFertility.Expr1")
    }
    jt <- content(rsp, type = "text", encoding = "UTF-8")
    cf <- fromJSON(jt, flatten = TRUE)

    # value is not NULL then use it else keep default NA
    if (!cf$Page$IsNull)
    {
      childlessnessMat[k, j] = cf$Page$Value
    }
    runIdx <- runIdx + 1
  }
}

#
# display the results
#
persp(
  x = scaleValues,
  y = scaleValues,
  z = childlessnessMat,
  zlim = range(childlessnessMat, na.rm = TRUE),
  xlab = "Decreased union formation",
  ylab = "Decreased fertility",
  zlab = "Childlessness",
  theta = 30, phi = 30, expand = 0.5, ticktype = "detailed",
  col = "lightgreen",
  cex.axis = 0.7
)
