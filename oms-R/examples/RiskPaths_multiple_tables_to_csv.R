#
# Read multiple tables from multiple model runs and save each table valaues as TableName.csv
#
library("jsonlite")
library("httr")

# Include openM++ helper functions from your $HOME directory
#
source("~/omsCommon.R")

#
# Model digest of RiskPaths version 3.0.0.0: "d90e1e9a49a06d972ecf1d50e684c62b"
# We MUST use model digest if there are multiple versions of the model published.
# We can use model name if only single version of the model is published.
#
md <- "d90e1e9a49a06d972ecf1d50e684c62b"

# oms web-service URL from file: ~/oms_url.txt
#
apiUrl <- getOmsApiUrl()

# model runs can be identified by digest, by run stamp or by run name
# run digest is unique and it preferable way to identify model run
# run names are user friendly may not be unique
#
runNames <- c(
  "New 123,000 cases",
  "New 456,000 cases",
  "New 789,000 cases"
  )

# for each table do:
#   combine all run results and write it into TableName.csv
#
tblNames <- c(
  "T04_FertilityRatesByAgeGroup",
  "T03_FertilityByAge"
  )

nTbls <- length(tblNames)
nRuns <- length(runNames)

for (j in 1:nTbls)
{

  allCct <- NULL

  for (k in 1:nRuns)
  {
    cct <- read.csv(paste0(
      apiUrl, "model/", md, "/run/", URLencode(runNames[k], reserved = TRUE), "/table/", tblNames[j], "/expr/csv"
      ))
    cct$RunName <- runNames[k]
 
    allCct <- rbind(allCct, cct)
  }

  write.csv(allCct, paste0(tblNames[j], ".csv"), row.names = FALSE)
}

