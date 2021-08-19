#/bin/bash
[[ -f $HOME/.bashrc ]] && source $HOME/.bashrc -start "echo dummy"

# Set default script's parameters
# ---
declare HB_USERKEY="KEY4BACKUP"
declare OV_BACKUP_TYPE="com"
declare HB_BACKUP_TYPE="c"
declare HB_ASYNC=0
declare OV_DATABASES="%all"
declare HB_DATABASES=""
declare HB_FILE_PREFIX=""
declare HB_FILE_SUFFIX=$(date +"%Y%m%d")
declare HB_OPTIONS=""
declare HB_COMMENT=""

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
    hanabackup.sh -dbs %all

Options:
    -U  <HANA User Key from secure user store>
        The default user key is '${HB_USERKEY}'.

    --backup_type <type-of-backup>
        The default backup type is '${OV_BACKUP_TYPE}'.

    --async, -A
        Switch asynchronous calling of the BACKUP DATA SQL-statement.

    --dbs <Comma-separated databases list>
        List of databases for backup.
        You can use the string '%all' for backup all of databases.
        The default value is '${OV_DATABASES}'.

    --help
        Display this help and exit.

Authors:
    - Mikhail Prusov, mprusov@sapbasis.ru
EOF
}

exitWithError() {
    echo "error: ${1}. Terminated with code ${2}..." >&2 ; exit $2
}

logInfo() {
    echo "info: $1"
}

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
        HB_USERKEY=$2
        shift 2
        ;;
    --async|-A)
        HB_ASYNC=1
        shift 1
        ;;
    --backup_type)
        OV_BACKUP_TYPE=$2
        shift 2
        ;;
    --dbs)
        OV_DATABASES=$2
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

# Construst hdbsql calling
# ---
HDBSQL="$DIR_EXECUTABLE/hdbsql -U ${HB_USERKEY}"
HDBSQL_BACKUP="$HDBSQL -x -quiet -j -a"
HDBSQL_QUERY="$HDBSQL -x -quiet -j -a -C"

# Parse backup mode ^w[S|M]?:
# ---
parseWeekBackupPlan() {
    # Build full week backup plan
    # ---
    WBP="${BASH_REMATCH[2]}-------"
    WBP=$(echo ${WBP:0:7} | tr '[:upper:]' '[:lower:]')
    [[ "${BASH_REMATCH[1]}" = "M" ]] && WBP="${WBP:6:1}${WBP:0:6}"

    # Evalute day of week
    # ---
    DOW=$(date +%u)

    # Evalute HB_BACKUP_TYPE
    # ---
    HB_BACKUP_TYPE="${WBP:$DOW:1}"
}

# Prepare list of all databases
# ---
prepareListAllDatabases() {
    GET_LIST_OF_DATABASES_SQL="SELECT DATABASE_NAME FROM M_DATABASES"
    logInfo "Try to execute the SQL-command with \"$HDBSQL_QUERY\":"
    logInfo "    \"$GET_LIST_OF_DATABASES_SQL\""
    GET_LIST_OF_DATABASES_RES=$($HDBSQL_QUERY "$GET_LIST_OF_DATABASES_SQL")
    HB_DATABASES=$GET_LIST_OF_DATABASES_RES
}

# Parse option value OV_BACKUP_TYPE
# ---
if [[ "$OV_BACKUP_TYPE" =~ ^w([S|M])?:([cCiIdD-]*)$ ]]; then
    parseWeekBackupPlan
else
    case $(echo $OV_BACKUP_TYPE | tr '[:upper:]' '[:lower:]') in
        c|com|d|dif|i|inc)
            HB_BACKUP_TYPE=${OV_BACKUP_TYPE:0:1}
            ;;
        *)
            exitWithError "Specified backup type '${OV_BACKUP_TYPE}' is unknown. You can use next backup types: com, dif, inc..." -1
            ;;
    esac
fi

# Parse option value OV_DATABASES
# ---
if [[  "$OV_DATABASES" == "%all" ]]; then
    prepareListAllDatabases
else
    HB_DATABASES=$(echo $OV_DATABASES | tr ',' ' ')
fi

# Evaluate HB_DELTA_SQL
# ---
case "$HB_BACKUP_TYPE" in
    c)
        HB_DELTA_SQL=""
        ;;
    d)
        HB_DELTA_SQL="DIFFERENTIAL"
        ;;
    i)
        HB_DELTA_SQL="INCREMENTAL"
        ;;
esac

# Evaluate HB_FILE_PREFIX_SQL
# ---
if [[ -z "$HB_FILE_PREFIX" ]]; then
    case "$HB_BACKUP_TYPE" in
        c)
            HB_FILE_PREFIX="COMPLETE_DATA_BACKUP_"
            ;;
        d)
            HB_FILE_PREFIX="DIFFERENTIAL_DATA_BACKUP_"
            ;;
        i)
            HB_FILE_PREFIX="INCREMENTAL_DATA_BACKUP_"
            ;;
    esac
fi
HB_FILE_PREFIX_SQL="$HB_FILE_PREFIX$HB_FILE_SUFFIX"

#
#
[[ $HB_ASYNC == 1 ]] && HB_OPTIONS="$HB_OPTIONS ASYNCHRONOUS"

# Start backups for selected HANA databases
# ---
for HB_DATABASE in $HB_DATABASES; do
    HB_COMMAND_SQL="BACKUP DATA $HB_DELTA_SQL FOR $HB_DATABASE USING FILE ( '$HB_FILE_PREFIX_SQL' )${HB_OPTIONS}${HB_COMMENT_SQL}"
    logInfo "Try to execute the SQL-command with \"$HDBSQL_BACKUP\":"
    logInfo "    \"$HB_COMMAND_SQL\""
    $HDBSQL_BACKUP $HB_COMMAND_SQL
    logInfo "The backup of the database \"$HB_DATABASE\" is complete."
done
