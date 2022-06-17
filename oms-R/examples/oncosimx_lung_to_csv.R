#
# Use R to run OncoSimX-lung version 3.5.0.90
#   loop over LcScreenSmokingDurationCriteria parameter
#   to output tables: Lung_Cancer_Rates_AgeStandard_Table and Lung_Cancer_Cases_Table
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
# Model digest of OncoSimX-lung version 3.5.0.90: "ec388f9e6221e63ac248818b04633515"
#
md <- "b4aac07eb78f31f3fcb7bbb3057c27b8"

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

# Use openM++ oms web-service to run the model 4 times with 6000 simulation cases
# and different values of LcScreenSmokingDurationCriteria parameter:
#
# OncoSimX-lung_mpi -Parameter.SimulationCases 6000 -Parameter.LcScreenSmokingDurationCriteria 1
# OncoSimX-lung_mpi -Parameter.SimulationCases 6000 -Parameter.LcScreenSmokingDurationCriteria 3
#   .... and 2 more Smoking Duration values ....
#
# Use back-end cluster to run the model with 12 sub-values on 4 servers and 3 theards
#
nRuns <- 4
smokingDuration <- seq(from = 1, by = 2, length.out = nRuns)

runDigests <- rep('', nRuns)  # model run digests, unique
runNames <- rep('', nRuns)    # model run names, may be not unique

for (k in 1:nRuns)
{
  print(c("Smoking Duration:", smokingDuration[k]))
  
  rn <- paste0("Smoking_Duration_", toString(smokingDuration[k]))
  runNames[k] <- rn
  
  # prepare model run options
  pd <- list(
      ModelDigest = md,
      Mpi = list(Np = 5),                      # MPI cluster: run 5 processes
      Template = "mpi.OncoSimX.template.txt",  # MPI cluster: model run tempate
      Opts = list(
        Parameter.LcScreenSmokingDurationCriteria = toString(smokingDuration[k]),
        Parameter.SimulationCases = "6000",
        OpenM.BaseRunDigest = firstRunDigest,  # base run to get the rest of input parameters
        OpenM.SubValues = "12",                # use 12 sub-values (sub-samples)
        OpenM.Threads = "3",                   # use 3 modeling threads
        OpenM.NotOnRoot = "true",              # MPI cluster: do not use root process for modelling
          # run name and description in English
        OpenM.RunName = rn,
        EN.RunDescription = paste("Smoking Duration", toString(smokingDuration[k]), "years")
      ),
      Tables = list("Lung_Cancer_Rates_AgeStandard_Table", "Lung_Cancer_Cases_Table")
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
  rStamp <- jr$RunStamp  # model run stamp

  # wait until model run completed
  runDigests[k] <- waitForRunCompleted(rStamp, apiUrl, md)
}

# combine all run results into Lung_Cancer_Cases_Table.csv 
#
print("All model runs completed, retrive output values...")

allCct <- NULL

for (k in 1:nRuns)
{
  cct <- read.csv(paste0(
    apiUrl, "model/", md, "/run/", runDigests[k], "/table/Lung_Cancer_Cases_Table/expr/csv"
    ))
  cct$RunName <- runNames[k]
  
  allCct <- rbind(allCct, cct)
}

write.csv(allCct, "Lung_Cancer_Cases_Table.csv", row.names = FALSE)
