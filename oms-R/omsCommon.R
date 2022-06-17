library("jsonlite")
library("httr")

#
# Return oms API URL, for example: http://localhost:4040/api/
#
# If environment variable OMS_URL defined then return "$OMS_URL/api/"
# If file oms_url.txt exist in current directory then read file and return first line + "/api/"
# If file $HOME/oms_url.txt exist then read file and return first line + "/api/"
# Else return "http://localhost:4040/api/"
#
getOmsApiUrl <- function()
{
  u <- Sys.getenv("OMS_URL")
  if (u != "") return(paste0(u, "/api/"))

  p <- ""
  if (file.exists(paste0("oms_url.txt"))) p <- paste0("oms_url.txt")
  if (p == "" && file.exists(paste0("~/oms_url.txt"))) p <- paste0("~/oms_url.txt")
  if (p != "") {
    u <- suppressWarnings(read.table(p, header = FALSE, sep = "", nrows = 1))
  }
  if (u != "") return(paste0(u, "/api/"))

  return("http://localhost:4040/api/")
}

#
# Wait until model run completed
#
# runStamp          - model run stamp
# apiUrl            - backend web-service URL
# modelNameOrDigest - model name or model digest
#
# return: model run digest
#
waitForRunCompleted <- function(runStamp, apiUrl, modelNameOrDigest)
{
  rDigest <- ""  # return run digest

  nSleep <- 1  # seconds, time to sleep between checking model run status
  nWait <- 20  # seconds, model run timeout: max time for model to start 
  n <- 0
  status <- ""
  
  while (status == "" || status == "i" || status == 'p')
  {
    Sys.sleep(nSleep)
    n <- n + 1

    # get model run status
    rsp <- GET(paste0(
      apiUrl, "model/", modelNameOrDigest, "/run/", runStamp, "/status"
    ))
    if (http_type(rsp) != 'application/json') {
      stop("Failed to get run status ", runStamp)
    }
    jr <- content(rsp)
    status <- jr$Status

    if (status == "s") {  # model run completed successfully
      rDigest <- jr$RunDigest
      break
    }
    if (status == 'p') {  # run not completed
      next
    }
    if (status == "" || status == "i") {  # run not started yet
      if (n < nWait) {
        next  # wait more for model run to start
      }
      stop("Model run failed to start: ", runStamp)  # model run start timeout, it takes too long
    }
    # else: model run failed

    stop("Model run failed: ", runStamp, ", status: ", status)
  }

  return(rDigest)
}

#
# Wait until modeling task completed
#
# taskName          - modeling task name
# taskRunStamp      - taskl run stamp
# apiUrl            - backend web-service URL
# modelNameOrDigest - model name or model digest
#
# return: list of run digests
#
waitForTaskCompleted <- function(taskName, taskRunStamp, apiUrl, modelNameOrDigest)
{
  runDigests <- c()

  nSleep <- 1  # seconds, time to sleep between checking model run status
  nWait <- 20  # seconds, model run timeout: max time for model to start 
  n <- 0
  status <- ""
  
  while (status == "" || status == "i" || status == 'p' || status == 'w')
  {
    Sys.sleep(nSleep)
    n <- n + 1
    nCompleted <- length(runDigests)

    # get task run status
    rsp <- GET(paste0(
      apiUrl, "model/", modelNameOrDigest, "/task/", taskName, "/run-status/run/", taskRunStamp
    ))
    if (http_type(rsp) != 'application/json') {
      stop("Failed to get task run status ", taskRunStamp)
    }
    jr <- content(rsp)
    status <- jr$Status


    if (status == "s" || status == "p" || status == "w")  # run completed successfully or run in progress
    {

      # get status of each model run
      rsp <- GET(paste0(
        apiUrl, "model/", modelNameOrDigest, "/run/", taskRunStamp, "/status/list"
      ))
      if (http_type(rsp) != 'application/json') {
        stop("Failed to get run status ", taskRunStamp)
      }
      jr <- content(rsp)
      
      for (r in jr)
      {
        if (r$Status == "s") {
          if (!any(runDigests == r$RunDigest)) runDigests <- c(runDigests, r$RunDigest)
        }
      }
      if (length(runDigests) != nCompleted) print(paste("Runs completed:", length(runDigests)))
      
      if (status == "s") break  # task run completed
      next  # continue wait
    }
    if (status == "" || status == "i") {  # run not started yet
      if (n < nWait) {
        next  # wait more for model run to start
      }
      stop("Model run failed to start: ", taskRunStamp)  # model run start timeout, it takes too long
    }
    # else: task run failed

    stop("Task run failed: ", taskRunStamp, ", status: ", status)
  }

  return(runDigests)
}
