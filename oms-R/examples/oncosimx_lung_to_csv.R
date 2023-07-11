#
# Use R to run OncoSimX-lung version 3.6.1.5
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
# Model digest of OncoSimX-lung version 3.6.1.5: "eeb246bd7d3bdb64d3e7aaefeaa828ea"
#
md <- "eeb246bd7d3bdb64d3e7aaefeaa828ea"

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
# It is MPI model on small computational cluster of 4 servers
# running 5 OncoSimX-lung_mpi instancces: "root" leader process and 4 computational processes
# each computational process using modelling 3 threads
# root process does only database operations and coordinate child workoload.
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
  # use explicit model run stamp to avoid compatibility issues between cloud model run queue and desktop MPI
  stamp <- sub('.' , '_', fixed = TRUE, format(Sys.time(),"%Y_%m_%d_%H_%M_%OS3"))

  # prepare model run options
  pd <- list(
      ModelDigest = md,
      Mpi = list(
        Np = 4,               # MPI cluster: run 4 processes: 3 for model and rott process
        IsNotOnRoot = TRUE    # MPI cluster: do not use root process for modelling
      ),
      Template = "mpi.OncoSimX.template.txt",  # MPI cluster: model run template
      Opts = list(
        Parameter.LcScreenSmokingDurationCriteria = toString(smokingDuration[k]),
        Parameter.SimulationCases = "6000",    # use only 6000 simulation cases for quick test
        OpenM.BaseRunDigest = firstRunDigest,  # base run to get the rest of input parameters
        OpenM.SubValues = "12",                # use 12 sub-values (sub-samples)
        OpenM.Threads = "4",                   # use 4 modeling threads
        OpenM.RunStamp = stamp,                # use explicit run stamp
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
  submitStamp <- jr$SubmitStamp # model run submission stamp: not empty if model run submitted to run on cluster
  runStamp <- jr$RunStamp       # model run stamp: not empty if model run started

  # wait until model run completed
  runDigests[k] <- waitForRunCompleted(stamp, apiUrl, md)
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
