#
# Read multiple tables from multiple model runs and save each table values as TableName.csv
# Also save model runs metadata and tables metadata (name, description, notes) into .csv files
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

# output tables to retrieve data from
#
tblNames <- c(
  "T04_FertilityRatesByAgeGroup",
  "T03_FertilityByAge"
  )

# get table information
#
rsp <- GET(paste0(
    apiUrl, "model/", md, "/text"
  ))
if (http_type(rsp) != 'application/json') {
  stop("Failed to get first model info")
}
jr <- content(rsp)
tTxt <- jr$TableTxt

tableInfo <- data.frame()

for (t in tTxt) {
  for (tbl in tblNames)
  {
    if (t$Table$Name == tbl) {
      ti <- data.frame(
          TableName = tbl,
          TableDescription = t$TableDescr,
          TableNotes = t$TableNote
        )
      tableInfo <- rbind(tableInfo, ti)
      break
    }
  }
}

# save table information into some .csv file
#
write.csv(tableInfo, "tableInfo.csv", row.names = FALSE)

# get run information
#
runInfo <- data.frame()

for (run in runNames)
{
  rsp <- GET(paste0(
      apiUrl, "model/", md, "/run/", URLencode(run, reserved = TRUE), "/text"
    ))
  if (http_type(rsp) != 'application/json') {
    stop("Failed to get first run info of: ", run)
  }
  jr <- content(rsp)
  ri <- data.frame(
      ModelName = jr$ModelName,
      ModelVersion = jr$ModelVersion,
      RunName = jr$Name,
      SubCount = jr$SubCount,
      RunStarted = jr$CreateDateTime,
      RunCompleted = jr$UpdateDateTime,
      RunDescription = "",
      RunNotes = ""
    )
  if (length(jr$Txt) > 0) {
    ri$RunDescription <- jr$Txt[[1]]$Descr
    ri$RunNotes <- jr$Txt[[1]]$Note
  }
 
  runInfo <- rbind(runInfo, ri)
}

# save run information into some .csv file
#
write.csv(runInfo, "runInfo.csv", row.names = FALSE)

# combine all run results and write it into T04_FertilityRatesByAgeGroup.csv
#

allCct <- NULL

for (run in runNames)
{
  cct <- read.csv(paste0(
    apiUrl, "model/", md, "/run/", URLencode(run, reserved = TRUE), "/table/T04_FertilityRatesByAgeGroup/expr/csv"
    ))
  cct$RunName <- run
 
  allCct <- rbind(allCct, cct)
}

write.csv(allCct, "T04_FertilityRatesByAgeGroup.csv", row.names = FALSE)
