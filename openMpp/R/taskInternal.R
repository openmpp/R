##
## Copyright (c) 2014 OpenM++
## This is a free software licensed under MIT license
##

# 
# For internal use only, it MUST be in transaction scope
#
# Update modeling task text: name, description, notes
#
# dbCon     - database connection
# defRs     - model definition database rows
# i_taskId  - modeling task id
# i_taskTxt - (optional) task text data frame:
#   $name   - task name
#   $lang   - language code
#   $descr  - task description
#   $note   - (optional) task notes
#
updateTaskTxt <- function(dbCon, defRs, i_taskId, i_taskTxt = NA)
{
  # validate input parameters
  if (missing(dbCon)) stop("invalid (missing) database connection")
  if (is.null(dbCon) || !is(dbCon, "DBIConnection")) stop("invalid database connection")
  
  # get list of languages and validate task text
  isAnyTaskTxt <- validateTxtFrame("modeling task text", defRs$langLst, i_taskTxt)
  if (!isAnyTaskTxt) return(NULL)
  
  #
  # update task name
  #
  taskName <- ifelse(isAnyTaskTxt, i_taskTxt$name, NA)
  if (is.na(taskName)) taskName <- paste("task_", i_taskId, sep = "")
  
  dbExecute(
    dbCon, 
    paste(
      "UPDATE task_lst SET task_name = ", toQuoted(taskName), " WHERE task_id = ", i_taskId,
      sep = ""
    )
  )
    
  #
  # delete existing task text
  # insert task text rows where language and description non-empty
  #
  dbExecute(
    dbCon, 
    paste(
      "DELETE FROM task_txt WHERE task_id = ", i_taskId,
      sep = ""
    )
  )
  sqlInsTxt <-
    paste(
      "INSERT INTO task_txt (task_id, lang_id, descr, note)",
      " SELECT",
      " T.task_id,",
      " (SELECT L.lang_id FROM lang_lst L WHERE L.lang_code = :lang),",
      " :descr,",
      " :note",
      " FROM task_lst T WHERE T.task_id = ", i_taskId,
      sep = ""
    )
  dbExecute(
    dbCon, 
    sqlInsTxt,
    params = subset(i_taskTxt, !is.na(lang) & !is.na(descr), select = c(lang, descr, note))
  )
}

# 
# For internal use only, it MUST be in transaction scope
#
# insert additional workset ids as task input into task_set table
#
# dbCon    - database connection
# i_taskId - modeling task id
# i_setIds - (optional) workset ids of the task (vector of input ids)
#   it can be scalar value, vector or data frame
#   if scalar then it must be positive integer
#   if vector then it must be vector of positive integers
#   if data frame then it must have $set_id column with positive integers
#   and in any case all id values must exist in workset_lst.set_id db-table
#
updateTaskSetIds <- function(dbCon, i_taskId, i_setIds = NA)
{
  # validate input parameters
  if (missing(dbCon)) stop("invalid (missing) database connection")
  if (is.null(dbCon) || !is(dbCon, "DBIConnection")) stop("invalid database connection")
  
  # check if any workset ids specified as arguments
  isAnySetId <- !missing(i_setIds) 
  if (isAnySetId) isAnySetId <- !is.null(i_setIds) && !is.na(i_setIds)
  if (!isAnySetId) return(NULL)
  
  # validate set ids: integer vector of id's expected
  idDf <- NULL
  
  if (isAnySetId) {
    isScalar <- length(i_setIds) == 1 && !is.data.frame(i_setIds) && !is.list(i_setIds)
    isVector <- !isScalar && is.vector(i_setIds) && !is.list(i_setIds)
    isFrame <- !isScalar && !isVector && is.data.frame(i_setIds)
    
    if (!isScalar && !isVector && !isFrame) stop("workset ids must be scalar, vector or data frame")

    if (isScalar || isVector) {
      if (!is.numeric(i_setIds)) stop("workset ids must integer")
      idDf <- data.frame(ne_id = i_setIds, set_id = i_setIds)
    }
    # if set ids is a frame then it expected to have $set_id column
    if (isFrame) {
      if (is.null(i_setIds$"set_id")) stop("workset ids data frame must have $set_id column")
      if (!is.numeric(i_setIds$"set_id")) stop("workset ids must integer")
      idDf <- data.frame(ne_id = i_setIds$set_id, set_id = i_setIds$set_id)
    }

    if (is.null(idDf)) stop("invalid (or missing) workset ids")
  }
  
  #
  # validate set id: it must be integer and exist in workset_lst
  #
  res <- dbSendQuery(
    dbCon, 
    paste(
      "SELECT :ne_id FROM task_lst T",
      " WHERE T.task_id = ", i_taskId,
      " AND NOT EXISTS (SELECT 1 FROM workset_lst W WHERE W.set_id = :set_id)", 
      sep = ""
    ),
    params = idDf[which(!is.na(idDf$set_id)), ]
  )
  
  idRs <- dbFetch(res, 10)
  dbClearResult(res)
  if (nrow(idRs) > 0L) stop("invalid (non-existing) workset id's (up to first 10): ", paste(idRs$ne_id, collapse = ", "))

  #
  # append workset into task_set if not already exists
  #
  dbExecute(
    dbCon, 
    paste(
      "INSERT INTO task_set (task_id, set_id)",
      " SELECT L.task_id, :ne_id FROM task_lst L",
      " WHERE L.task_id = ", i_taskId,
      " AND NOT EXISTS (SELECT S.set_id FROM task_set S WHERE S.task_id = L.task_id AND S.set_id = :set_id)",
      sep = ""
    ),
    params = idDf[which(!is.na(idDf$set_id)), ]
  )
}
