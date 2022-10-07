#
# Read table values from multiple model runs and save it as XLSX file
# Model run names and table names are coming from another input XLSX file
#

# If jsonlite, httr, readxl or writexl is not installed then do:
#   install.packages("jsonlite")
#   install.packages("httr")
#   install.packages("readxl")
#   install.packages("writexl")
#
library("jsonlite")
library("httr")
library("readxl")
library("writexl")

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
# read model run names from some XLSX file, 
#   it must have sheet name = "RunNames" with A column "RunNames"
#
rn <- read_xlsx(
  "model-runs-to-read-and-tables-to-read.xlsx", 
  sheet = "RunNames", 
  col_types = "text"
  )

# read table names from some XLSX file, 
#   it must have sheet name = "TableNames" with A column "TableNames"
#
tn <- read_xlsx(
  "model-runs-to-read-and-tables-to-read.xlsx",
  sheet = "TableNames",
  col_types = "text"
  )

# for each table do:
#   combine all run results and write it into TableName.csv
#

shts <- list()

for (tbl in tn$TableNames)
{

  allCct <- NULL

  for (run in rn$RunNames)
  {
    cct <- read.csv(paste0(
      apiUrl, "model/", md, "/run/", URLencode(run, reserved = TRUE), "/table/", tbl, "/expr/csv"
      ))
    cct$RunName <- run
 
    allCct <- rbind(allCct, cct)
  }
  shts[[ tbl ]] <- allCct
}

write_xlsx(shts, paste0("some-name-here.xlsx"))
