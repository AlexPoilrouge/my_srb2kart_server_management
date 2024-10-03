#!/bin/bash

THIS_SCRIPT="$( realpath "$0" )"
SCRIPT_DIR="$( dirname "$( realpath "$0" )" )"


VALUES_FILES="${SCRIPT_DIR}/operator_values.env"
# provides:
#   - RACER_SERVER_SERVICE envvar
#   - RACER_SERVER_CMD_START envvar
#   - RACER_SERVER_CMD_RESTART envvar
#   - RACER_SERVER_CMD_STOP envvar
source "${VALUES_FILES}"


RACER_MODE_INFO_FILE="${SCRIPT_DIR}/state.txt"
RACER_PASSWORD_FILE="${SCRIPT_DIR}/.TMP_PASS"
RACER_LOGFILE="${SCRIPT_DIR}/log.txt"

ADDONS_DIR="${SCRIPT_DIR}/addons"
ADDONS_INSTALLED_SUBDIR="${ADDONS_DIR}/installed"
ADDONS_ENABLED_SUBDIR="${ADDONS_DIR}/enabled"
ADDONS_PENDING_OPS_JSON_FILE="${ADDONS_DIR}/pending_op.json"


SERVCMD_COOLDOWN_FILEBASE="${SCRIPT_DIR}/.service_op_cooldown"
SERVCMD_COOLDOWN_PERIOD=180

cmd_serv(){
    OP="$1"
    _CMD_VAR="RACER_SERVER_CMD_${OP}"
    CMD="$(eval echo \${${_CMD_VAR}})"

    SERVCMD_COOLDOWN_FILE="${SERVCMD_COOLDOWN_FILEBASE}_${OP}"
    CURRENT_TIME=$(date +%s)
    CAN_DO="true"
    
    if [ ! -f "$SERVCMD_COOLDOWN_FILE" ]; then
        CAN_DO="true"
    else
        LAST_SERVCMD_TIME="$( cat "${SERVCMD_COOLDOWN_FILE}" )"
        TIME_DIFF="$((CURRENT_TIME - LAST_SERVCMD_TIME))"

        if [ "$TIME_DIFF" -lt "$SERVCMD_COOLDOWN_PERIOD" ]; then
            CAN_DO="false"
        fi
    fi

    if "${CAN_DO}"; then
        echo "${CURRENT_TIME}" > "${SERVCMD_COOLDOWN_FILE}"

        eval sudo "${CMD}"

        echo "{ \"state\": \"ok\" }"
    else
        REMAINING_TIME="$(( SERVCMD_COOLDOWN_PERIOD - TIME_DIFF ))"

        echo -e "{\n    \"state\": \"cooldown\",\n    \"remaining_seconds\": ${REMAINING_TIME}\n}"
    fi
}


CMD="$1"
shift

case "${CMD}" in
"INIT")
    mkdir -p "${ADDONS_DIR}"

    if [ -f "${RACER_LOGFILE}" ]; then
        chmod 704 "${RACER_LOGFILE}"
    fi

    if [ ! -f "${RACER_MODE_INFO_FILE}" ]; then
        echo "{"modes": []}" > "${RACER_MODE_INFO_FILE}"
    fi
    chmod 704 "${RACER_MODE_INFO_FILE}"

    exit 0
;;
"" | "IS_SERVICE_ACTIVE")
    if systemctl is-active "${RACER_SERVER_SERVICE}" >/dev/null 2>&1; then
        echo "active"
        exit 0
    else
        echo "inactive"
        exit 1
    fi
;;
"START")
    cmd_serv START
;;
"RESTART")
    cmd_serv RESTART
;;
"STOP")
    cmd_serv STOP
;;
"MODE_INFO")
    if [ -f "${RACER_MODE_INFO_FILE}" ]; then
        cat "${RACER_MODE_INFO_FILE}"
    else
        exit 2
    fi
;;
"GET_PASSWORD")
    if [ -f "${RACER_PASSWORD_FILE}" ]; then
        cat "${RACER_PASSWORD_FILE}"
    else
        exit 3
    fi
;;
"PENDING_DELETES" | "PENDING_DISABLES")
    FORCE="$( echo "$1" | tr '[:upper:]' '[:lower:]' )"
    shift
    if [ "${FORCE}" == "force" ] || ( ! "${THIS_SCRIPT}" IS_SERVICE_ACTIVE ); then
        exec {LOCK_PID}>>"${ADDONS_PENDING_OPS_JSON_FILE}"

        OP_FIELD="disablement"
        if [ "${CMD}" == "PENDING_DELETES" ]; then
            OP_FIELD="deletion"
        fi

        if flock -w 3 ${LOCK_PID}; then
            jq ".${OP_FIELD}[]" "${ADDONS_PENDING_OPS_JSON_FILE}" 2>/dev/null  | tr -d '"' | while read -r FILE; do
                if [ -f "${ADDONS_INSTALLED_SUBDIR}/${FILE}" ]; then
                    rm -f "${ADDONS_ENABLED_SUBDIR}/${FILE}"
                    if [ "${CMD}" == "PENDING_DELETES" ]; then
                        rm -f "${ADDONS_INSTALLED_SUBDIR}/${FILE}"
                    fi
                fi
            done

            tmpfile="$( mktemp )"
            jq ".${OP_FIELD} = []" "${ADDONS_PENDING_OPS_JSON_FILE}" 2> /dev/null > "${tmpfile}" && mv "${tmpfile}" "${ADDONS_PENDING_OPS_JSON_FILE}"
        fi

        exec {LOCK_PID}>&-
    fi
;;
"PENDING")
    "${THIS_SCRIPT}" "PENDING_DISABLES" $@
    "${THIS_SCRIPT}" "PENDING_DELETES" $@
;;
*)
    echo "ERROR - Invalid $0 command…"
    exit 255
;;
esac

exit 0
