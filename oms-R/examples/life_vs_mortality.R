#
# R integration example using NewCaseBased model:
#   loop over MortalityHazard parameter
#   to analyze DurationOfLife
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
# Model name: NewCaseBased
#
# If you have multiple versions of the model with the same name
# then instead of:
#   ModelName = "NewCaseBased"
# use model digest to identify specific model version, for example:
#   ModelDigest = "ec388f9e6221e63ac248818b04633515"
#
md <- "NewCaseBased"

# oms web-service URL, it can be hard-coded, for example: "http://localhost:4040/api/"
#
apiUrl <- getOmsApiUrl()

# Find first model run to use it as our base run
#
# Parameter MortalityHazard is varied by this script
# and the rest of parameters we are getting from base model run
#
#
rsp <- GET(paste0(
    apiUrl, "model/", md, "/run/status/first"
  ))
if (http_type(rsp) != 'application/json') {
  stop("Failed to get first run status")
}
jr <- content(rsp)
firstRunDigest <- jr$RunDigest

# Use openM++ oms web-service to run NewCaseBased model 20 times with 5000 simulation cases
# and different values of MortalityHazard parameter:
#
# NewCaseBased.exe -Parameter.SimulationCases 5000 -Parameter.MortalityHazard 0.014
# NewCaseBased.exe -Parameter.SimulationCases 5000 -Parameter.MortalityHazard 0.019
#   .... and 18 more mortality hazard values ....
#
# For each request to run the model web-service respond with JSON containing RunStamp
# We can use this RunStamp to find model run status and results.
#
nRuns <- 20
mortality <- seq(from = 0.014, by = 0.005, length.out = nRuns)

runDigests <- rep('', nRuns)  # model run digests

for (k in 1:nRuns)
{
  print(c("Mortality Hazard:", mortality[k]))

  # use explicit model run stamp to avoid compatibility issues between cloud model run queue and desktop MPI
  stamp <- sub('.' , '_', fixed = TRUE, format(Sys.time(),"%Y_%m_%d_%H_%M_%OS3"))

  # prepare model run options
  pd <- list(
      ModelName = md,
      Opts = list(
        Parameter.MortalityHazard = toString(mortality[k]),
        Parameter.SimulationCases = "5000",
        OpenM.BaseRunDigest = firstRunDigest,  # base run to get the rest of input parameters
        OpenM.SubValues = "16",                # use 16 sub-values (sub-samples)
        OpenM.Threads = "4",                   # use 4 modeling threads
        OpenM.ProgressPercent = "100",         # reduce amount of progress messages in the log file
        OpenM.RunStamp = stamp,                # use explicit run stamp
          # run name and description in English
        OpenM.RunName = paste("Mortality Hazard", toString(mortality[k])),
        EN.RunDescription = paste("model run with mortality hazard", toString(mortality[k]))
      )
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

# for each run get output value
#   average duration of life: DurationOfLife.Expr3
#
print("All model runs completed, retrive output values...")

pd <- list(
    Name = "DurationOfLife",
    ValueName = "Expr3",
    Size = 0             # Size = 0 means read all rows of DurationOfLife.Expr3
  )
jv <- toJSON(pd, pretty = TRUE, auto_unbox = TRUE)

lifeDuration <- rep(NA, nRuns)

for (k in 1:nRuns)
{
  rsp <- POST(paste0(
          apiUrl, "model/", md, "/run/", runDigests[k], "/table/value"
      ),
      body = jv,
      content_type_json()
    )
  if (http_type(rsp) != 'application/json') {
    stop("Failed to get output value [", k, "] ", runDigests[k])
  }
  jt <- content(rsp, type = "text", encoding = "UTF-8")
  dl <- fromJSON(jt, flatten = TRUE)

  lifeDuration[k] <- dl$Page$Value
}

#
# display the results
#
plot(
  mortality,
  lifeDuration,
  type = "o",
  xlab = "Mortality Hazard",
  ylab = "Duration of Life",
  col = "red"
)
