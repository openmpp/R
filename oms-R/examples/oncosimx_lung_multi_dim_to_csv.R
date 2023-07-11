#
# Use R to run OncoSimX-lung version 3.6.1.5
#   run model 12 times changing two multi-dimensional parameters:
#   LcDispatcherDefault and SwitchEligibilityRule
#   import Lung_Cancer_Rates_AgeStandard_Table and Lung_Cancer_Cases_Table output tables into CSV files.
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
# Model digest of OncoSimX-lung version 3.6.1.5: "eeb246bd7d3bdb64d3e7aaefeaa828ea"
#
md <- "eeb246bd7d3bdb64d3e7aaefeaa828ea"

# oms web-service URL from file: ~/oms_url.txt
#
apiUrl <- getOmsApiUrl()

# Use base run digest to get all initial parameter values
#
baseRunDigest <- "227b97f7b1ec91e9958d8723241f4df9"

# get initial values of LcDispatcherDefault and SwitchEligibilityRule
# by reading it from base run results
#
rsp <- GET(paste0(
    apiUrl, "model/", md, "/run/", baseRunDigest, "/parameter/LcDispatcherDefault/value/start/0/count/0"
  ))
if (http_type(rsp) != 'application/json') {
  stop("Failed to get parameter LcDispatcherDefault")
}
lcDispatcherDefault <- content(rsp)

rsp <- GET(paste0(
    apiUrl, "model/", md, "/run/", baseRunDigest, "/parameter/SwitchEligibilityRule/value/start/0/count/0"
  ))
if (http_type(rsp) != 'application/json') {
  stop("Failed to get parameter SwitchEligibilityRule")
}
switchEligibilityRule <- content(rsp)

# Create multiple input scenarios with parameters:
#
#   LcDispatcherDefault:
#       [[LUNG_SCREENING_x_MIN_RECRUIT_AGE, 0]] values: 42, 45, 50
#       [[LUNG_SCREENING_x_MAX_RECRUIT_AGE, 4]] values: 70, 80
#
#   SwitchEligibilityRule 2 sets:
#       set TRUE values for: [[PLCOm2012s]], [[Smoke_duration]], [[AND_OR_check_uncheck]]
#       set TRUE values for: [[Pack_year_NLST]]
#
serPLCOm2012sAndDuration <- switchEligibilityRule

for (k in 1:length(serPLCOm2012sAndDuration)) {
  if (serPLCOm2012sAndDuration[[k]]$Dims[[1]] == "PLCOm2012s" || serPLCOm2012sAndDuration[[k]]$Dims[[1]] == "Smoke_duration" || serPLCOm2012sAndDuration[[k]]$Dims[[1]] == "AND_OR_check_uncheck") {
    serPLCOm2012sAndDuration[[k]]$Value <- TRUE
  } else {
    serPLCOm2012sAndDuration[[k]]$Value <- FALSE
  }
}

serPackNLST <- switchEligibilityRule

for (k in 1:length(serPackNLST)) {
  if (serPackNLST[[k]]$Dims[[1]] == "Pack_year_NLST") {
    serPackNLST[[k]]$Value <- TRUE
  } else {
    serPackNLST[[k]]$Value <- FALSE
  }
}

# create input scenarios
#
nameLst <- c()  # input scenario names, automatically generated
runNames <- c() # run names based on scenario parameters values
labelLst <- c() # input scenarios description
serLabel <- ""

for (nSe in 1:2) {

  if (nSe == 1) {
    ser <- serPLCOm2012sAndDuration
    serLabel <- "PLCOm2012s_and_Smoke_duration"
  } else {
    ser <- serPackNLST
    serLabel <- "Pack_year_NLST"
  }
  
  for (lcdMinPr0 in c(42, 45, 50)) {
    for (lcdMaxPr4 in c(70, 80)) {
    
      lcd <- lcDispatcherDefault
      lcd[[which(sapply(lcd, function(x) x$Dims[[1]] == "LUNG_SCREENING_x_MIN_RECRUIT_AGE" && x$Dims[[2]] == "0"))]]$Value <- lcdMinPr0
      lcd[[which(sapply(lcd, function(x) x$Dims[[1]] == "LUNG_SCREENING_x_MAX_RECRUIT_AGE" && x$Dims[[2]] == "4"))]]$Value <- lcdMaxPr4

      # run name and scenario description
      rn <- paste0("EligibilityRule_", serLabel, "_MinAge_", lcdMinPr0, "_MaxAge_", lcdMaxPr4)
      runNames <- c(runNames, rn)

      label <- paste("SwitchEligibilityRule:", serLabel, "LcDispatcherDefault Min Age:", lcdMinPr0, "LcDispatcherDefault Max Age:", lcdMaxPr4)
      print(label)  # show progress
      
      # create new input scenario
      # automatically generate unique names for each input scenario
      #
      pd <- list(
        ModelDigest = md,   # model digest of OncoSimX-breast
        IsReadonly = TRUE,  # allow to run the model with that input scenario
        Txt = list(
          list(LangCode = "EN",  Descr = label)
        ),
        Param = list(
          list(
            Name = "SwitchEligibilityRule",
            SubCount = 1,
            Value = ser,
            Txt = list(
              list(LangCode = "EN", Note = paste("Eligibility Rule: ", serLabel))
            )
          ),
          list(
            Name = "LcDispatcherDefault",
            SubCount = 1,
            Value = lcd,
            Txt = list(
              list(LangCode = "EN", Note = paste("Min Age:", lcdMinPr0, "Max Age:", lcdMaxPr4))
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

      if (is.na(sn) || sn == "") stop("Fail to create input set:", serName, lcdMinPr0, lcdMaxPr4)

      nameLst <- c(nameLst, sn)       # append new scenario name into name list
      labelLst <- c(labelLst, label)  # append scenario description to the list
    }
  }
}

# Use openM++ oms web-service to run the model for all scenarios with 5000 simulation cases
# and different scenario parameters SwitchEligibilityRule and LcDispatcherDefault:
#
# OncoSimX-lung_mpi -Parameter.SimulationCases 5000 -OpenM.SetName set_1234
# OncoSimX-lung_mpi -Parameter.SimulationCases 5000 -OpenM.SetName set_567
# ........
#
# It is a sequential run, not parallel.
#
# Running 4 OncoSimX-lung_mpi instances: "root" leader process and 3 computational processes
# each computational process using modelling 4 threads
# root process does only database operations and coordinate child workoload.
#
nRuns <- length(nameLst)
runDigests <- rep('', nRuns)  # model run digests, unique

for (k in 1:nRuns)
{
  print(runNames[k])

  # use explicit model run stamp to avoid compatibility issues between cloud model run queue and desktop MPI
  stamp <- sub('.' , '_', fixed = TRUE, format(Sys.time(),"%Y_%m_%d_%H_%M_%OS3"))

  # prepare model run options
  pd <- list(
      ModelDigest = md,
      Mpi = list(
        Np = 4,               # MPI cluster: run 4 processes: 3 for model and root process
        IsNotOnRoot = TRUE    # MPI cluster: do not use root process for modelling
      ),
      Template = "mpi.OncoSimX.template.txt",  # MPI cluster: model run template
      Opts = list(
        OpenM.SetName = nameLst[k],
        Parameter.SimulationCases = "5000",    # use only 5000 simulation cases for quick test
        OpenM.BaseRunDigest = baseRunDigest,   # base run to get the rest of input parameters
        OpenM.SubValues = "12",                # use 12 sub-values (sub-samples)
        OpenM.Threads = "4",                   # use 4 modeling threads
        OpenM.RunStamp = stamp,                # use explicit run stamp
         # run name and description in English
        OpenM.RunName = runNames[k],
        EN.RunDescription = labelLst[k]
      ),
      Tables = list("Lung_Cancer_Rates_AgeStandard_Table ", "Lung_Cancer_Cases_Table")
    )
  jv <- toJSON(pd, pretty = TRUE, auto_unbox = TRUE)

  # submit request to web-service to run the model
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
  submitStamp <- jr$SubmitStamp # model run submission stamp: not empty if model run submitted to run on cluster
  runStamp <- jr$RunStamp       # model run stamp: not empty if model run started

  # wait until model run completed
  runDigests[k] <- waitForRunCompleted(stamp, apiUrl, md)
}

# combine all run results into Lung_Cancer_Rates_AgeStandard_Table.csv and Lung_Cancer_Cases_Table.csv
#
print("All model runs completed, retrive output values...")

allCct <- NULL
allCrt <- NULL

for (k in 1:nRuns)
{
  cct <- read.csv(paste0(
    apiUrl, "model/", md, "/run/", runDigests[k], "/table/Lung_Cancer_Cases_Table/expr/csv"
    ))
  cct$RunLabel <- labelLst[k]

  allCct <- rbind(allCct, cct)

  crt <- read.csv(paste0(
    apiUrl, "model/", md, "/run/", runDigests[k], "/table/Lung_Cancer_Rates_AgeStandard_Table/expr/csv"
    ))
  crt$RunLabel <- labelLst[k]

  allCrt <- rbind(allCrt, crt)
}

write.csv(allCct, "Lung_Cancer_Cases_Table.csv", row.names = FALSE)
write.csv(allCrt, "Lung_Cancer_Rates_AgeStandard_Table.csv", row.names = FALSE)

# Cleanup:
# delete all input scenarios

for (sn in nameLst)
{
  print(paste("Delete", sn))

  rsp <- POST(paste0(apiUrl, "model/", md, "/workset/", sn, "/readonly/false"))
  stop_for_status(rsp, paste("update read-only status of input set", sn))

  rsp <- DELETE(paste0(apiUrl, "model/", md, "/workset/", sn))
  stop_for_status(rsp, paste("delete input set", sn))
}
