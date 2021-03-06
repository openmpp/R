##
## Copyright (c) 2014 OpenM++
## This is a free software licensed under MIT license
##

# 
# Create new modeling task
#
# Return task id of new task or <= 0 on error
#
# dbCon    - database connection
# defRs    - model definition database rows
# taskTxt  - (optional) task text data frame:
#   $name  - task name
#   $lang  - language code
#   $descr - task description
#   $note  - (optional) task notes
# setIds   - (optional) workset ids of the task (vector of input ids)
#   it can be scalar value, vector or data frame
#   if scalar then it must be positive integer
#   if vector then it must be vector of positive integers
#   if data frame then it must have $set_id column with positive integers
#   and in any case all id values must exist in workset_lst.set_id db-table
#
createTask <- function(dbCon, defRs, taskTxt = NA, setIds = NA)
{
  # validate input parameters
  if (missing(dbCon)) stop("invalid (missing) database connection")
  if (is.null(dbCon) || !is(dbCon, "DBIConnection")) stop("invalid database connection")
  
  if (missing(defRs)) stop("invalid (missing) model definition")
  if (is.null(defRs) || is.na(defRs) || !is.list(defRs)) stop("invalid or empty model definition")
  
  # create new task in transaction scope
  taskId <- 0L
  
  isTrxCompleted <- FALSE;
  tryCatch({
    dbBegin(dbCon)

    # get next task id
    dbExecute(dbCon, "UPDATE id_lst SET id_value = id_value + 1 WHERE id_key = 'run_id_set_id'")
    idRs <- dbGetQuery(dbCon, "SELECT id_value FROM id_lst WHERE id_key = 'run_id_set_id'")
    if (nrow(idRs) <= 0L || idRs$id_value <= 0L) stop("can not get new task id from id_lst table")
    
    taskId <- idRs$id_value
  
    # create task with auto-name
    dbExecute(
      dbCon, 
      paste(
        "INSERT INTO task_lst (task_id, model_id, task_name) VALUES (",
        taskId, ", ",
        defRs$modelDic$model_id, ", ",
        toQuoted(paste("task_", taskId, sep = "")), " )",
        sep = ""
      )
    )
    
    # set task text: name, description notes
    updateTaskTxt(dbCon, defRs, taskId, taskTxt)
    
    # append workset ids
    updateTaskSetIds(dbCon, taskId, setIds)
    
    isTrxCompleted <- TRUE; # completed OK
  },
  finally = {
    ifelse(isTrxCompleted, dbCommit(dbCon), dbRollback(dbCon))
  })
  return(ifelse(isTrxCompleted, taskId, 0L))
}

# 
# Update modeling task: 
#   update task text (name, description, notes)
#   insert additional workset ids as task input
#
# Return task id task or <= 0 on error
#
# dbCon    - database connection
# defRs    - model definition database rows
# taskId   - modeling task id
# taskTxt  - (optional) task text data frame:
#   $name  - task name
#   $lang  - language code
#   $descr - task description
#   $note  - (optional) task notes
# setIds   - (optional) workset ids of the task (vector of input ids)
#   it can be scalar value, vector or data frame
#   if scalar then it must be positive integer
#   if vector then it must be vector of positive integers
#   if data frame then it must have $set_id column with positive integers
#   and in any case all id values must exist in workset_lst.set_id db-table
#
updateTask <- function(dbCon, defRs, taskId, taskTxt = NA, setIds = NA)
{
  # validate input parameters
  if (missing(dbCon)) stop("invalid (missing) database connection")
  if (is.null(dbCon) || !is(dbCon, "DBIConnection")) stop("invalid database connection")
  
  if (missing(defRs)) stop("invalid (missing) model definition")
  if (is.null(defRs) || is.na(defRs) || !is.list(defRs)) stop("invalid or empty model definition")
  
  if (missing(taskId) || is.null(taskId) || !is.numeric(taskId)) stop("invalid or empty modeling task id")
  
  # update existing task in transaction scope
  isTrxCompleted <- FALSE;
  
  tryCatch({
    dbBegin(dbCon)

    # check if task exist
    idRs <- dbGetQuery(dbCon, 
      paste(
        "SELECT task_id FROM task_lst WHERE task_id = ", taskId, 
        sep = ""
      )
    )
    if (nrow(idRs) <= 0L || idRs$task_id != taskId) stop("invalid (non-existing) task id :", taskId)
    
    # set task text: name, description notes
    updateTaskTxt(dbCon, defRs, taskId, taskTxt)
    
    # append workset ids
    updateTaskSetIds(dbCon, taskId, setIds)
    
    isTrxCompleted <- TRUE; # completed OK
  },
  finally = {
    ifelse(isTrxCompleted, dbCommit(dbCon), dbRollback(dbCon))
  })
  return(ifelse(isTrxCompleted, taskId, 0L))
}

# 
# Set modeling task "wait completed" status
#
# Return task run id or <= 0 on error
#
# dbCon           - database connection
# taskRunId       - id of modeling task
# isWaitCompleted - if TRUE then task ready to be completed
#
setTaskWaitCompleted <- function(dbCon, taskRunId, isWaitCompleted = FALSE)
{
  # validate input parameters
  if (missing(dbCon)) stop("invalid (missing) database connection")
  if (is.null(dbCon) || !is(dbCon, "DBIConnection")) stop("invalid database connection")
  
  if (missing(taskRunId) || is.null(taskRunId) || !is.numeric(taskRunId)) stop("invalid or empty task run id")
  
  # update task in transaction scope
  isTrxCompleted <- FALSE;
  
  tryCatch({
    dbBegin(dbCon)
    
    # check if task exist
    dbExecute(dbCon, 
      paste(
        "UPDATE task_run_lst", 
        " SET status = CASE",
        " WHEN status = 'w' THEN ", ifelse(isWaitCompleted, "'p'", "'w'"),
        " ELSE status",
        " END,",
        " update_dt = ", toQuoted(format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
        " WHERE task_run_id = ", taskRunId, 
        sep = ""
      )
    )

    isTrxCompleted <- TRUE; # completed OK
  },
  finally = {
    ifelse(isTrxCompleted, dbCommit(dbCon), dbRollback(dbCon))
  })
  return(ifelse(isTrxCompleted, taskRunId, 0L))
}
