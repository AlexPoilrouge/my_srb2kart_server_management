#!/bin/bash


SCRIPT_DIR="$( dirname "$( realpath "$0" )" )"


VALUES_FILES="${SCRIPT_DIR}/operator_values.env"

source "${VALUES_FILES}"


RACER_MODE_INFO_FILE="${SCRIPT_DIR}/state.txt"
RACER_PASSWORD_FILE="${SCRIPT_DIR}/.TMP_PASS"


CMD="$1"

case "${CMD}" in
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
*)
    echo "ERROR - Invalid $0 command…"
    exit 255
;;
esac

exit 0
