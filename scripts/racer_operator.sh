#!/bin/bash

THIS_SCRIPT="$( realpath "$0" )"
SCRIPT_DIR="$( dirname "$( realpath "$0" )" )"


VALUES_FILES="${SCRIPT_DIR}/operator_values.env"

source "${VALUES_FILES}"


RACER_MODE_INFO_FILE="${SCRIPT_DIR}/state.txt"
RACER_PASSWORD_FILE="${SCRIPT_DIR}/.TMP_PASS"
RACER_LOGFILE="${SCRIPT_DIR}/log.txt"

ADDONS_DIR="${SCRIPT_DIR}/addons"
ADDONS_INSTALLED_SUBDIR="${ADDONS_DIR}/installed"
ADDONS_ENABLED_SUBDIR="${ADDONS_DIR}/enabled"
ADDONS_PENDING_OPS_JSON_FILE="${ADDONS_DIR}/pending_op.json"


pendingOps_process(){

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
"PENDING_DELETES")
    FORCE="$( echo "$1" | tr '[:upper:]' '[:lower:]' )"
    shift
    if [ "${FORCE}" == "force" ] || ( ! "${THIS_SCRIPT}" IS_SERVICE_ACTIVE ); then
        exec {LOCK_PID} >> "${ADDONS_PENDING_OPS_JSON_FILE}"

        if flock -w 3 ${LOCK_PID}; then
            yq e '.deletion[]' "${ADDONS_PENDING_OPS_JSON_FILE}" | tr -d '"' | while read -r FILE; do
                if [ -f "${ADDONS_INSTALLED_SUBDIR}/${FILE}" ]; then
                    rm -f "${ADDONS_INSTALLED_SUBDIR}/${FILE}"
                fi
            done

            yq e '.deletion = []' -i "${ADDONS_PENDING_OPS_JSON_FILE}"
        fi

        exec {LOCK_PID} >&-
    fi
;;
"PENDING_DISABLES")
    FORCE="$( echo "$1" | tr '[:upper:]' '[:lower:]' )"
    shift
    if [ "${FORCE}" == "force" ] || ( ! "${THIS_SCRIPT}" IS_SERVICE_ACTIVE ); then 
        exec {LOCK_PID} >> "${ADDONS_PENDING_OPS_JSON_FILE}"
        
        if flock -w 3 ${LOCK_PID}; then
            yq e '.disablement[]' "${ADDONS_PENDING_OPS_JSON_FILE}" | tr -d '"' | while read -r FILE; do
                if [ -f "${ADDONS_ENABLED_SUBDIR}/${FILE}" ]; then
                    rm -f "${ADDONS_ENABLED_SUBDIR}/${FILE}"
                fi
            done

            yq e '.disablement = []' -i "${ADDONS_PENDING_OPS_JSON_FILE}"
        fi

        exec {LOCK_PID} >&-
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
