#
# Use R to run OncoSimX-breast version 3.6.1.5
# loop over parameters:
#   BreastScreeningProtocolDispatcher, BreastScreeningSnSpOddMultiplierAge, BreastScreeningCosts
# to produce output tables:
#   Breast_Cancer_Cases_Table and Breast_Cancer_Rates_Table
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
# Model digest of OncoSimX-breast version 3.6.1.5: "528f94c1525c994b010d84507ed7903f"
#
md <- "528f94c1525c994b010d84507ed7903f"

# oms web-service URL from file: ~/oms_url.txt
#
apiUrl <- getOmsApiUrl()

# Find first model run to use it as our base run
#
rsp <- GET(paste0(
    apiUrl, "model/", md, "/run/status/first"
  ))
if (http_type(rsp) != 'application/json') {
  stop("Failed to get first run status")
}
jr <- content(rsp)
firstRunDigest <- jr$RunDigest

# get initial values of: BreastScreeningProtocolDispatcher, BreastScreeningSnSpOddMultiplierAge, BreastScreeningCosts
# by reading it from first model run results
#
rsp <- GET(paste0(
    apiUrl, "model/", md, "/run/", firstRunDigest, "/parameter/BreastScreeningProtocolDispatcher/value/start/0/count/0"
  ))
if (http_type(rsp) != 'application/json') {
  stop("Failed to get parameter BreastScreeningProtocolDispatcher")
}
protocolDispatcher <- content(rsp)

rsp <- GET(paste0(
    apiUrl, "model/", md, "/run/", firstRunDigest, "/parameter/BreastScreeningSnSpOddMultiplierAge/value/start/0/count/0"
  ))
if (http_type(rsp) != 'application/json') {
  stop("Failed to get parameter BreastScreeningSnSpOddMultiplierAge")
}
multiplierAge <- content(rsp)

rsp <- GET(paste0(
    apiUrl, "model/", md, "/run/", firstRunDigest, "/parameter/BreastScreeningCosts/value/start/0/count/0"
  ))
if (http_type(rsp) != 'application/json') {
  stop("Failed to get parameter BreastScreeningCosts")
}
screeningCosts <- content(rsp)

# Create multiple input scenarios with parameters:
#
#   BreastScreeningProtocolDispatcher:   2 values, scale down by 2%
#   BreastScreeningSnSpOddMultiplierAge: 2 values, scale down by 1%
#   BreastScreeningCosts:                2 values, scale up by 3%
#
scalePD <- seq(from = 1, by = -0.02, length.out = 2)
scaleMA <- seq(from = 1, by = -0.01, length.out = 2)
scaleSC <- seq(from = 1, by = 0.03, length.out = 2)

nameLst <- c()  # input scenario names, automatically generated
labelLst <- c() # input scenarios description

for (scPD in scalePD)
{
  # scale BreastScreeningProtocolDispatcher values
  vpd <- protocolDispatcher
  for (k in 1:length(vpd))
  {
    vpd[[k]]$Value <- protocolDispatcher[[k]]$Value * scPD
  }

  for (scMA in scaleMA)
  {
    # scale BreastScreeningSnSpOddMultiplierAge values
    vma <- multiplierAge
    for (k in 1:length(vma))
    {
      vma[[k]]$Value <- multiplierAge[[k]]$Value * scMA
    }

    for (scSC in scaleSC)
    {
      # scale BreastScreeningCosts values
      vsc <- screeningCosts
      for (k in 1:length(vsc))
      {
        vsc[[k]]$Value <- screeningCosts[[k]]$Value * scSC
      }

      # show progress
      print(paste("BreastScreeningProtocolDispatcher:", scPD))
      print(paste("BreastScreeningSnSpOddMultiplierAge:", scMA))
      print(paste("BreastScreeningCosts:", scSC))

      # create new input scenario
      # automatically generate unique names for each input scenario
      #
      label <- paste("ProtocolDispatcher: ", scPD, " MultiplierAge: ", scMA, " ScreeningCosts: ", scSC)
      pd <- list(
          ModelDigest = md,   # model digest of OncoSimX-breast
          IsReadonly = TRUE,  # allow to run the model with that input scenario
          Txt = list(
            list(LangCode = "EN",  Descr = label)
          ),
          Param = list(
            list(
              Name = "BreastScreeningProtocolDispatcher",
              SubCount = 1,
              Value = vpd,
              Txt = list(
                list(LangCode = "EN", Note = paste("BreastScreeningProtocolDispatcher: ", scPD))
              )
            ),
            list(
              Name = "BreastScreeningSnSpOddMultiplierAge",
              SubCount = 1,
              Value = vma,
              Txt = list(
                list(LangCode = "EN", Note = paste("BreastScreeningSnSpOddMultiplierAge: ", scMA))
              )
            ),
            list(
              Name = "BreastScreeningCosts",
              SubCount = 1,
              Value = vsc,
              Txt = list(
                list(LangCode = "EN", Note = paste("BreastScreeningCosts: ", scSC))
              )
            )
          )
        )
      jv <- toJSON(pd, auto_unbox = TRUE)

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

      if (is.na(sn) || sn == "") stop("Fail to create input set, scales:", scPD, scMA, scSC)

      nameLst <- c(nameLst, sn)       # append new scenario name into name list
      labelLst <- c(labelLst, label)  # append scenario description to the list
    }
  }
}

# Create modeling task from all input sets
# automatically generate unique name for the task
#
n <- length(nameLst)

print(paste("Create task from", n, "input scenarios"))

pd <- list(
    ModelDigest = md,  # model digest of OncoSimX-breast
    Set = nameLst,     # list of input scenarios included into modelling task
    Txt = list(
      list(LangCode = "EN", Descr = paste("Task to run OncoSimX-breast", n, "times"))
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
# Run OncoSimX-breast with modeling task and wait until task is completed
# It is a sequential run, not parallel.
#
# Running 4 OncoSimX-breast_mpi instances: "root" leader process and 3 computational processes
# each computational process using modelling 4 threads
# root process does only database operations and coordinate child workoload.
#
print(paste("Starting modeling task:", taskName))

# use explicit model run stamp to avoid compatibility issues between cloud model run queue and desktop MPI
stamp <- sub('.' , '_', fixed = TRUE, format(Sys.time(),"%Y_%m_%d_%H_%M_%OS3"))

  pd <- list(
    ModelDigest = md,
    Mpi = list(
      Np = 4,               # MPI cluster: run 4 processes: 3 for model and rott process
      IsNotOnRoot = TRUE    # MPI cluster: do not use root process for modelling
    ),
    Template = "mpi.OncoSimX.template.txt",  # MPI cluster: model run template
    Opts = list(
      OpenM.TaskName = taskName,             # modelling task to run
      OpenM.RunStamp = stamp,                # use explicit run stamp
      Parameter.SimulationCases = "6000",    # use 6000 simulation cases to get quick results
      OpenM.BaseRunDigest = firstRunDigest,  # base run to get the rest of input parameters
      OpenM.SubValues = "12",                # use 12 sub-values (sub-samples)
      OpenM.Threads = "4"                    # use 4 modeling threads
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

# combine all run results into Breast_Cancer_Cases_Table.csv and Breast_Cancer_Rates_Table.csv
#
print("All model runs completed, retrive output values...")

nRuns <- length(runDigests)
allCct <- NULL
allCrt <- NULL

for (k in 1:nRuns)
{
  cct <- read.csv(paste0(
    apiUrl, "model/", md, "/run/", runDigests[k], "/table/Breast_Cancer_Cases_Table/expr/csv"
    ))
  cct$RunLabel <- labelLst[k]

  allCct <- rbind(allCct, cct)

  crt <- read.csv(paste0(
    apiUrl, "model/", md, "/run/", runDigests[k], "/table/Breast_Cancer_Rates_Table/expr/csv"
    ))
  crt$RunLabel <- labelLst[k]

  allCrt <- rbind(allCrt, crt)
}

write.csv(allCct, "Breast_Cancer_Cases_Table.csv", row.names = FALSE)
write.csv(allCrt, "Breast_Cancer_Rates_Table.csv", row.names = FALSE)

# Cleanup:
# delete modelling task
# delete all input scenarios

print(paste("Delete", taskName))

rsp <- DELETE(paste0(apiUrl, "model/", md, "/task/", taskName))
stop_for_status(rsp, "delete modelling task")

for (sn in nameLst)
{
  print(paste("Delete", sn))

  rsp <- POST(paste0(apiUrl, "model/", md, "/workset/", sn, "/readonly/false"))
  stop_for_status(rsp, paste("update read-only status of input set", sn))

  rsp <- DELETE(paste0(apiUrl, "model/", md, "/workset/", sn))
  stop_for_status(rsp, paste("delete input set", sn))
}
