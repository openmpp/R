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
# Model digest of OncoSimX-cervical version 3.6.0.89: "1e2779c60cd69e746996eafcf17be5d8"
# We MUST use model digest if there are multiple versions of the model published.
# We can use model name if only single version of the model is published.
#
md <- "1e2779c60cd69e746996eafcf17be5d8"

# oms web-service URL from file: ~/oms_url.txt
#
apiUrl <- getOmsApiUrl()

# model runs can be identified by digest, by run stamp or by run name
# run digest is unique and it preferable way to identify model run
# run names are user friendly but may not be unique
#
runList <- read.csv("run_list.csv")

# output tables to retrieve data from
#
tblNames <- c(
  "Cervical_Cancer_Cases_Table",
  "Cervical_Cancer_ICER_Table_Discounted",
  "HPV_Colposcopy_Results_Table",
  "Hpv_Screening_Costs_Prov_Table"
  )

# get table information
# and save it into Table-Name.table-info.csv file
#
rsp <- GET(paste0(
    apiUrl, "model/", md, "/text"
  ))
if (http_type(rsp) != 'application/json') {
  stop("Failed to get first model info")
}
jr <- content(rsp)
tTxt <- jr$TableTxt

for (t in tTxt) {
  for (tbl in tblNames)
  {
    if (t$Table$Name == tbl) {

      ti <- data.frame(
        TableName = tbl,
        TableDescription = t$TableDescr,
        TableNotes = t$TableNote
        )
      write.csv(ti, paste0(tbl, ".table-info.csv"), row.names = FALSE)
      break
    }
  }
}

# get run information
# and save it into run-info.Model-Run-Name.csv file
#

for (run in runList$Name)
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

  write.csv(ri, paste0("run-info.", run, ".csv"), row.names = FALSE)
}

# for each table
#   retrieve all accumulators for all model runs
#   and write it into Table-Name.all-acc.csv
#

for (tbl in tblNames)
{
  print( paste("Get", tbl, sep=": ") )
  
  allCct <- NULL

  for (run in runList$Name)
  {
    cct <- read.csv(paste0(
      apiUrl, "model/", md, "/run/", URLencode(run, reserved = TRUE), "/table/", tbl, "/all-acc/csv"
      ))
    cct$RunName <- run
 
    allCct <- rbind(allCct, cct)
  }

  write.csv(allCct, paste0(tbl, ".all-acc.csv"), row.names = FALSE)
}

# for each measure do:
#   read accumulators and sub-values .all-acc.csv file
#   transform table data by moving sub-values from rows to columns: sub0,sub1,...,sub11
#   add extra columns:
#     Eavg: mean of each row
#     Esd:  standard deviation of each row
#     Ecv:  coefficient of variation of each row as: 100 * SD / mean
#   write results into Table-Name.Measure-Name.avg-sd-cv.csv file
#
writeAvgSdCv <- function(tblName, tblDims, tblMeas, subCount)
{

  lastSub <- subCount - 1L
  subNames <- c( paste0("sub", seq(0, lastSub)) )
  
  # for each measure do:
  #
  for (mName in tblMeas)
  {
    print(paste(tblName, mName, sep=": "))
    
    # read all accumulators from CSV
    #
    srcAllAcc <- read.csv(paste0(tblName, ".all-acc.csv"))
    
    # transform table data by moving sub-values from rows to columns: sub0,sub1,...,sub11
    #
    tData <- srcAllAcc[which(srcAllAcc$sub_id == 0), c("RunName", tblDims, mName)]
    
    for (n in 1:lastSub)
    {
      tData <- cbind(tData, srcAllAcc[which(srcAllAcc$sub_id == n), c(mName)])
    }
    names(tData) <- c("RunName", tblDims, subNames) # rename columns into sub0,sub1,...,sub11
    
    # add extra columns: mean, SD, CV
    #
    tData$Eavg <- apply( tData[, subNames], 1, mean )
    tData$Esd <- apply( tData[, subNames], 1, sd )
    tData$Ecv <- apply( tData[, subNames], 1, function(x) 100 * sd(x) / mean(x) )
    
    write.csv(tData, paste0(tblName, ".", mName, ".avg-sd-cv.csv"), row.names = FALSE)
  }
}

# OncoSimX-cervical model runs contains 12 sub-values (a.k.a. sub-samples)
#
subCount <- 12L

# Cervical_Cancer_Cases_Table:
#   Dimensions: Province, Year
#   and 14 measures
#
tblName <- "Cervical_Cancer_Cases_Table"

tblDims <- c(
  "Province", "Year"
  )
tblMeas <- c(
  "Incidence_cases",
  "False_incidenc_x_for_no_reason",
  "Cervical_cance_x_ected_by_screen",
  "Cervical_cance_x_ormer_screeners",
  "Cervical_cance_x_ormer_screener4",
  "Interval_cervical_cancers",
  "Adenocarcinoma_incidence_cases",
  "Squamous_cell_x_incidence_cases",
  "Cancer_inciden_x_duced_by_HPV_16",
  "Cancer_inciden_x_duced_by_HPV_18",
  "Cancer_inciden_x_other_HPV_types",
  "Prevalence_cases",
  "Prevalence_person_years",
  "Deaths_cause_specific"
  )

writeAvgSdCv(tblName, tblDims, tblMeas, subCount)

# Cervical_Cancer_ICER_Table_Discounted:
#   Dimensions: Discounting_horizons, Province, Discount_rate
#   and 8 measures
#
tblName <- "Cervical_Cancer_ICER_Table_Discounted"

tblDims <- c(
  "Discounting_horizons", "Province", "Discount_rate"
  )
tblMeas <- c(
  "Total_cost_va_x_all_treatment",
  "Cost_of_HPV_vaccination",
  "Cost_of_screening",
  "Pre_cervical_c_x_warts_excluded",
  "Wart_treatment_costs",
  "Cost_of_cancer_treatment",
  "Person_years","Health_adjusted_person_years"
  )

writeAvgSdCv(tblName, tblDims, tblMeas, subCount)

# HPV_Colposcopy_Results_Table:
#   Dimensions: Age_group, Colposcopy_results, Year
#   and only one measure
#
tblName <- "HPV_Colposcopy_Results_Table"

tblDims <- c(
  "Age_group", "Colposcopy_results", "Year"
  )
tblMeas <- c(
  "Colposcopy_count"
  )

writeAvgSdCv(tblName, tblDims, tblMeas, subCount)

# Hpv_Screening_Costs_Prov_Table:
#   Dimensions: Sex, Province, Year
#   and 16 measures
#
tblName <- "Hpv_Screening_Costs_Prov_Table"

tblDims <- c(
  "Sex", "Province", "Year"
  )
tblMeas <- c(
  "HPV_vaccine_costs",
  "Screening_cytology_costs",
  "Colposcopy_costs",
  "HPV_DNA_test_costs",
  "Pre_cervical_c_x_warts_excluded",
  "Cervical_Biopsy_cost",
  "Wart_treatment_costs",
  "Primary_cytology_screening_count",
  "Follow_up_cyto_x_ong_colposcopy",
  "Colposcopy_count",
  "Primary_HPV_DNA_screening_count",
  "Follow_up_HPV_DNA_test_count",
  "Pre_cervical_c_x_warts_exclud12",
  "LEEP_count",
  "Cervical_Biopsy_count",
  "Number_of_people_person_years"
  )

writeAvgSdCv(tblName, tblDims, tblMeas, subCount)

