library("jsonlite")
library("httr")

#
# Login into openM++ cloud instance, return oms API and JWT login token.
#
# Following environmemnt variables are required:
#   OM_CLOUD_URL  - cloud URL, e.g.:       https://model.openmpp.org
#   OM_CLOUD_USER - user login name, e.g.: demo
#   OM_CLOUD_PWD  - login password, e.g.:  my-secret-password
#
loginToOpenmCloud <- function()
{
  omUrl <- Sys.getenv("OM_CLOUD_URL")
  omUsr <- Sys.getenv("OM_CLOUD_USER")
  omPwd <- Sys.getenv("OM_CLOUD_PWD")
  
  if (omUrl == "" || is.null(omUrl) || omUsr == "" || is.null(omUsr) || omPwd == "" || is.null(omPwd)) stop("OM_CLOUD_URL, OM_CLOUD_USER and OM_CLOUD_PWD must be defined")
  
  rsp <- POST(
      url = paste0(omUrl, '/login'),
      body = list(
        username=omUsr,
        password=omPwd
      ),
      encode = "form"
    )
  if (http_type(rsp) != 'application/jwt') {
    stop("Login FAILED")
  }
  print("Login OK")

  jwtToken <- rawToChar(content(rsp)) # get JWT token from response
  apiUrl <- paste0(omUrl, '/api/')    # oms web-service API URL

  if (jwtToken == "" || is.null(jwtToken)) stop("Invalid login, JWT token empty")

  return( list(apiUrl = apiUrl, loginToken = jwtToken) )
}

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
# stamp             - model run stamp
# apiUrl            - backend web-service URL
# modelNameOrDigest - model name or model digest
# loginToken        - if not missing then JWT login token
#
# return: model run digest
#
waitForRunCompleted <- function(stamp, apiUrl, modelNameOrDigest, loginToken)
{
  # check if it is a remote oms service in cloud: if JWT login token argument not missing
  jwtToken <- ""
  if (!missing(loginToken)) {
    if (is.null(loginToken) || loginToken == "") {
      stop("Invalid login, JWT token empty")
    }
    jwtToken <- loginToken
  }

  rDigest <- ""  # return run digest

  nSleep <- 1   # seconds, time to sleep between checking model run status
  nWait <- 180  # seconds, model run timeout: max time for model to start
  n <- 0
  status <- ""

  while (status == "" || status == "i" || status == 'p')
  {
    Sys.sleep(nSleep)
    n <- n + 1

    # get model run status
    rsp <- NULL
    if (jwtToken == "") {
      rsp <- GET(paste0(
            apiUrl, "model/", modelNameOrDigest, "/run/", stamp, "/status"
          ))
    } else {
      rsp <- GET(
          paste0(
            apiUrl, "model/", modelNameOrDigest, "/run/", stamp, "/status"
          ),
          set_cookies(jwt_token = jwtToken)
        )
    }
    if (is.null(rsp) || http_type(rsp) != 'application/json') {
      stop("Failed to get run status ", stamp)
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
      stop("Model run failed to start: ", stamp)  # model run start timeout, it takes too long
    }
    # else: model run failed

    stop("Model run failed: ", stamp, ", status: ", status)
  }

  return(rDigest)
}

#
# Wait until modeling task completed
#
# taskName          - modeling task name
# stamp             - model run stamp
# apiUrl            - backend web-service URL
# modelNameOrDigest - model name or model digest
# loginToken        - if not missing then JWT login token
#
# return: list of run digests
#
waitForTaskCompleted <- function(taskName, stamp, apiUrl, modelNameOrDigest, loginToken)
{
  # check if it is a remote oms service in cloud: if JWT login token argument not missing
  jwtToken <- ""
  if (!missing(loginToken)) {
    if (is.null(loginToken) || loginToken == "") {
      stop("Invalid login, JWT token empty")
    }
    jwtToken <- loginToken
  }

  runDigests <- c()

  nSleep <- 1   # seconds, time to sleep between checking model run status
  nWait <- 180  # seconds, model run timeout: max time for model to start
  n <- 0
  status <- ""

  while (status == "" || status == "i" || status == 'p' || status == 'w')
  {
    Sys.sleep(nSleep)
    n <- n + 1
    nCompleted <- length(runDigests)

    # get task run status
    rsp <- NULL
    if (jwtToken == "") {
      rsp <- GET(paste0(
            apiUrl, "model/", modelNameOrDigest, "/task/", taskName, "/run-status/run/", stamp
          ))
    } else {
      rsp <- GET(
          paste0(
            apiUrl, "model/", modelNameOrDigest, "/task/", taskName, "/run-status/run/", stamp
          ),
          set_cookies(jwt_token = jwtToken)
        )
    }
    if (is.null(rsp) || http_type(rsp) != 'application/json') {
      stop("Failed to get task run status ", stamp)
    }
    jr <- content(rsp)
    status <- jr$Status

    if (status == "s" || status == "p" || status == "w")  # run completed successfully or run in progress
    {

      # get status of each model run
      rsp <- NULL
      if (jwtToken == "") {
        rsp <- GET(paste0(
              apiUrl, "model/", modelNameOrDigest, "/run/", stamp, "/status/list"
            ))
      } else {
        rsp <- GET(
            paste0(
              apiUrl, "model/", modelNameOrDigest, "/run/", stamp, "/status/list"
            ),
            set_cookies(jwt_token = jwtToken)
          )
      }
      if (is.null(rsp) || http_type(rsp) != 'application/json') {
        stop("Failed to get run status ", stamp)
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
      stop("Model run failed to start: ", stamp)  # model run start timeout, it takes too long
    }
    # else: task run failed

    stop("Task run failed: ", stamp, ", status: ", status)
  }

  return(runDigests)
}
