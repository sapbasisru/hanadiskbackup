#/bin/bash
#
#
[[ -f $HOME/.bashrc ]] && source $HOME/.bashrc -start "echo dummy"

#######################################
# Runtime script's variables
# ---
# Script PID
declare HBS_MY_PID=$$

# Script trace level
declare HBS_TRACE_LEVEL=2

# Script's exit code
declare HBS_EXIT_CODE=0

#######################################
# Script's parameters
# ---
# User key for hdbsql
declare HBS_USERKEY="KEY4BACKUP"

# HANA backup's type (c|i|d)
declare HBS_BACKUP_TYPE="c"

# Backup starting mode (0 - sync, 1 - async)
declare HBS_ASYNC=0

# List of databases to backup
declare HBS_DATABASES=""

# HANA backup's file prefix
declare HBS_FILE_PREFIX=""

# HANA backup's file suffix
declare HBS_FILE_SUFFIX=$(date +"%Y%m%d")

# Additional HANA backup's options (if any)
declare HBS_OPTIONS=""

# HANA backup's comment
declare HBS_COMMENT=""

#######################################
# Input options
# ---
# Input option value for HANA backup's type
declare OPT_BACKUP_TYPE="com"

# Input option value for databases list
declare OPT_DATABASES="%all"

# Show utility's help
# ---
showHelp() {
cat<<EOF
Name
    hanabackup - HANA backup script.

Usage
    hanabackup.sh [OPTION...]

Description:

Examples:
    # start HANA backup for all tenant
    hanabackup.sh --dbs %all

Options:
    -U  <HANA User Key from secure user store>
        The default user key is '${HBS_USERKEY}'.

    --backup_type <type-of-backup>
        The default backup type is '${OPT_BACKUP_TYPE}'.

    --async, -A
        Switch asynchronous calling of the BACKUP DATA SQL-statement.

    --dbs <Comma-separated databases list>
        List of databases for backup.
        You can use the string '%all' for backup all of databases.
        The default value is '${OPT_DATABASES}'.

    --help
        Display this help and exit.

Authors:
    - Mikhail Prusov, mprusov@sapbasis.ru
EOF
}

#######################################
# Write log text (info, error, warning...)
# Globals:
#   HBS_MY_PID
# Arguments:
#   $1: Type of information (I, -, W, E)
#   $2: Text for writing
# Outputs:
#   Writes info to stdout/stderr
#######################################
logMessage() {
    local log_type=$1
    local my_pid=${HBS_MY_PID:-'-'}
    local timestamp=$(date '+%F %X %Z')
    local log_text=$2
    local log_message=""
    if [[ "$log_type" == "-" ]]; then
        log_message="$log_text"
    else
        log_message="$log_type $my_pid $timestamp: $log_text"
    fi
    # TODO[mprusov]: Logging to file is not implemented
    # [[ ! -z "$HBS_LOGFILE" ]] && echo "$__msg" >> $HBS_LOGFILE
    if [[ "$log_type" == "E" || "$log_type" == "W" ]]; then
        echo "$log_message" >&2
    elif [[ "$log_type" == "I" || "$log_type" == "-" ]]; then
        echo "$log_message" >&1
    else
        echo "$log_message" >&2
    fi
}

#######################################
# Log text info
# Arguments:
#   $1: Text for writing
# Outputs:
#   Writes info text to log
#######################################
logInfo() {
    logMessage 'I' "$1"
}

#######################################
# Log debug text info
# Arguments:
#   $1: Text for writing
# Outputs:
#   Writes info text to log
#######################################
debugInfo() {
    if [[ $HBS_TRACE_LEVEL > 1 ]]; then
        logMessage 'I' "$1"
    fi
}

#######################################
# Log error text info
# Arguments:
#   $1: Text for writing
# Outputs:
#   Writes info text to log
#######################################
errorInfo() {
    logMessage 'E' "$1"
}

#######################################
# Log error info
# Arguments:
#   $1: Text for writing
#   $2: Exit code (optional)
# Outputs:
#   Writes error text to log and exit
#######################################
exitWithError() {
    HBS_EXIT_CODE=${2:-'1'}
    errorInfo "${1}. Terminating with code ${HBS_EXIT_CODE}..."
    exit $HBS_EXIT_CODE
}

#######################################
# Construct hdbsql calling
# ---
HDBSQL="$DIR_EXECUTABLE/hdbsql -U ${HBS_USERKEY}"
HDBSQL_BACKUP="$HDBSQL -E 1 -x -quiet -j -a"
HDBSQL_QUERY="$HDBSQL -E 1 -x -quiet -j -a -C"

# Options for hdbsql-command for "BACKUP DATA..." SQL-statemnt
declare HBS_HDBSQL4B_OPT="-x -quiet -j -a"

# hdbsql-command for "BACKUP DATA..." SQL-statemnt
declare HBS_HDBSQL4B_CMD=""

# Options for hdbsql-command for any query SQL-statemnt
declare HBS_HDBSQL4Q_OPT="-x -quiet -j -a -C"

# hdbsql-command for any query SQL-statemnt
declare HBS_HDBSQL4Q_CMD=""

# hdbsql result string
declare HBS_HDBSQL_RESULT_STRING=""

# hdbsql exit code
declare HBS_HDBSQL_EXIT_CODE=0

#######################################
# Prepare command for calling of hdbsql
# Globals:
#   HBS_HDBSQL4B_CMD, HBS_HDBSQL4B_OPT
#   HBS_HDBSQL4Q_CMD, HBS_HDBSQL4Q_OPT
#   HBS_USERKEY
# Arguments:
#   none
# Outputs:
#   none
#######################################
prepareHDBSQLCommands() {
    local SELECT_FROM_DUMMY_SQL="SELECT * FROM DUMMY"
    # Construct and validate HBS_HDBSQL4B_CMD
    HBS_HDBSQL4B_CMD="$DIR_EXECUTABLE/hdbsql -U $HBS_USERKEY $HBS_HDBSQL4B_OPT"
    execHDBSQLBackup "$SELECT_FROM_DUMMY_SQL"
    if [[ $? != 0 ]]; then
        exitWithError "Validating of the hdbsql for backup is failed"
    fi
    # Construct and validate HBS_HDBSQL4Q_CMD
    HBS_HDBSQL4Q_CMD="$DIR_EXECUTABLE/hdbsql -U $HBS_USERKEY $HBS_HDBSQL4Q_OPT"
    execHDBSQLQuery "$SELECT_FROM_DUMMY_SQL"
    if [[ $? != 0 ]]; then
        exitWithError "Validating of the hdbsql for query is failed"
    fi

}

#######################################
# Execute SQL-command with hdbsql
# Globals:
#   HBS_HDBSQL_RESULT_STRING, HBS_HDBSQL_EXIT_CODE
# Arguments:
#   $1: command for hdbsql
#   $2: sql text to execute
#######################################
execHDBSQLCommand() {
    local hdbsql_cmd="$1"
    local sql_text="$2"
    debugInfo "Try to execute the SQL-command via hdbsql:"
    debugInfo "  hdbsql command is: \"$hdbsql_cmd\""
    debugInfo "  sql command is: \"$sql_text\""
    HBS_HDBSQL_RESULT_STRING=$($hdbsql_cmd "$sql_text")
    HBS_HDBSQL_EXIT_CODE=$?
    if [[ $HBS_HDBSQL_EXIT_CODE != 0 ]]; then
        errorInfo "Executing of the SQL-command is failed:"
        errorInfo "  sql command is: \"$sql_text\""
    else
        debugInfo "Executing of the SQL-command is successfully with result:"
        debugInfo "  result string is: \"$HBS_HDBSQL_RESULT_STRING\""
    fi
    return $HBS_HDBSQL_EXIT_CODE
}

#######################################
# Execute backup command with hdbsql
# Globals:
#   HBS_HDBSQL_RESULT_STRING, HBS_HDBSQL_EXIT_CODE
# Arguments:
#   $1: sql text to execute
#######################################
execHDBSQLBackup() {
    execHDBSQLCommand "$HBS_HDBSQL4B_CMD" "$1"
    return $?
}

#######################################
# Execute SQL-quert with hdbsql
# Globals:
#   HBS_HDBSQL_RESULT_STRING, HBS_HDBSQL_EXIT_CODE
# Arguments:
#   $1: sql text to execute
#######################################
execHDBSQLQuery() {
    HBS_HDBSQL_RESULT_STRING=""
    execHDBSQLCommand "$HBS_HDBSQL4Q_CMD" "$1"
    return $?
}

#######################################
# Parse backup mode ^w([S|M])?:([cCiIdD-]*)$
# Globals:
#   HBS_HDBSQL_RESULT_STRING, HBS_HDBSQL_EXIT_CODE
# Arguments:
#   $1: sql text to execute
#######################################
parseWeekBackupPlan() {
    # Build full week backup plan
    local week_plan="${BASH_REMATCH[2]}-------"
    week_plan=$(echo ${week_plan:0:7} | tr '[:upper:]' '[:lower:]')
    if [[ "${BASH_REMATCH[1]}" == "M" ]]; then
        week_plan="${week_plan:6:1}${week_plan:0:6}"
    fi
    debugInfo "The week's backup (starting from sunday) plan is \"$week_plan\""

    # Evalute day of week
    local day_of_week=$(date +%u)
    debugInfo "Today's day is \"$day_of_week\""

    # Evalute HBS_BACKUP_TYPE
    # ---
    HBS_BACKUP_TYPE="${week_plan:$day_of_week:1}"
    debugInfo "Today's backup type is \"$HBS_BACKUP_TYPE\""
}

# Prepare list of all databases
# ---
prepareListBackupDatabases() {
    GET_LIST_OF_DATABASES_SQL="SELECT DATABASE_NAME FROM M_DATABASES"
    execHDBSQLQuery "$GET_LIST_OF_DATABASES_SQL"
    if [[ $? != 0 ]]; then
        exitWithError "Can't get list of databses to backup"
    fi
    HBS_DATABASES=$HBS_HDBSQL_RESULT_STRING
}

#######################################
#### Main
##

logInfo "HANA Backup script started"

# Parse command line options
# ---
getopt --test &>/dev/null
if [[ $? -ne 4 ]]; then
    exitWithError "Getopt is too old" -2
fi

OPTS_SHORT="U:,A"
OPTS_LONG="help,async,backup_type:,dbs:"
OPTS=$(getopt -s bash -o '' --options $OPTS_SHORT --longoptions $OPTS_LONG -n "$0" -- "$@")
if [[ $? -ne 0 ]] ; then
    exitWithError "Failed parsing options" -2
fi
eval set -- "$OPTS"

while true; do
  case "$1" in
    -U)
        HBS_USERKEY=$2
        shift 2
        ;;
    --async|-A)
        HBS_ASYNC=1
        shift 1
        ;;
    --backup_type)
        OPT_BACKUP_TYPE=$2
        shift 2
        ;;
    --dbs)
        OPT_DATABASES=$2
        shift 2
        ;;
    --)
        shift
        break
        ;;
    *)
        showHelp
        exit 0
        ;;
  esac
done


# Prepare commands for calling hdbsql
# ---
prepareHDBSQLCommands

# Parse option value OPT_BACKUP_TYPE
# ---
if [[ "$OPT_BACKUP_TYPE" =~ ^w([S|M])?:([cCiIdD-]*)$ ]]; then
    parseWeekBackupPlan
else
    case $(echo $OPT_BACKUP_TYPE | tr '[:upper:]' '[:lower:]') in
        c|com|d|dif|i|inc)
            HBS_BACKUP_TYPE=${OPT_BACKUP_TYPE:0:1}
            ;;
        *)
            exitWithError "Specified backup type '${OPT_BACKUP_TYPE}' is unknown. You can use next backup types: com, dif, inc..." -1
            ;;
    esac
fi

# Parse option value OPT_DATABASES
# ---
if [[  "$OPT_DATABASES" == "%all" ]]; then
    prepareListBackupDatabases
else
    HBS_DATABASES=$(echo $OPT_DATABASES | tr ',' ' ')
fi

# Evaluate HBS_DELTA_SQL
# ---
declare HBS_DELTA_SQL=""

case "$HBS_BACKUP_TYPE" in
    d)
        HBS_DELTA_SQL="DIFFERENTIAL"
        ;;
    i)
        HBS_DELTA_SQL="INCREMENTAL"
        ;;
esac

# Evaluate HBS_FILE_PREFIX_SQL
# ---
declare HBS_FILE_PREFIX_SQL=""
if [[ -z "$HBS_FILE_PREFIX" ]]; then
    case "$HBS_BACKUP_TYPE" in
        c)
            HBS_FILE_PREFIX="COMPLETE_DATA_BACKUP_"
            ;;
        d)
            HBS_FILE_PREFIX="DIFFERENTIAL_DATA_BACKUP_"
            ;;
        i)
            HBS_FILE_PREFIX="INCREMENTAL_DATA_BACKUP_"
            ;;
    esac
fi
HBS_FILE_PREFIX_SQL="$HBS_FILE_PREFIX$HBS_FILE_SUFFIX"

# Add options ASYNCHRONOUS if set.
# ---
[[ $HBS_ASYNC == 1 ]] && HBS_OPTIONS="$HBS_OPTIONS ASYNCHRONOUS"

# Start backups for selected HANA databases
# ---
declare HBS_DATABASE=""
for HBS_DATABASE in $HBS_DATABASES; do
    HB_COMMAND_SQL="BACKUP DATA $HBS_DELTA_SQL FOR $HBS_DATABASE USING FILE ('$HBS_FILE_PREFIX_SQL')${HBS_OPTIONS}${HBS_COMMENT_SQL}"
    logInfo "Try to start the backup of the database \"$HBS_DATABASE\"..."
    execHDBSQLBackup "$HB_COMMAND_SQL"
    if [[ $? != 0 ]]; then
        exitWithError "Starting the backup of the database \"$HBS_DATABASE\" is failed"
    fi
    logInfo "Starting the backup of the database \"$HBS_DATABASE\" done successfully"
done

logInfo "HANA Backup script finished successfully"
