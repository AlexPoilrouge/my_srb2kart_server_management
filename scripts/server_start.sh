#!/bin/bash


SCRIPT_DIR="$( dirname "$( realpath "$0" )" )"


VALUES_FILES="${SCRIPT_DIR}/server_start.env"
# provides:
#   - STRASHBOT_USER_HOME envvar
#   - RACER_DIR envvar
#   - RACER_EXE envvar
#   - RACER_LAUNCH_ARGSenvvar
source "${VALUES_FILES}"


PASS="$( </dev/urandom tr -dc '0123456789azertyuiopqsdfghjklmwxcvbnAZERTYUIOPQSDFGHJKLMWXCVBN' | head -c6 )"

FILE="${SCRIPT_DIR}/.TMP_PASS"

echo "${PASS}" > "$FILE"

LOG_FILE="${STRASHBOT_USER_HOME}/${RACER_DIR}/log.txt"
LOGS_DIR="${STRASHBOT_USER_HOME}/${RACER_DIR}/logs"
mkdir -p "${LOGS_DIR}"
if [ -f "${LOG_FILE}" ]; then
    if "${RACER_HANDLE_LOGS}"; then
        cp -vf "${LOG_FILE}" "${LOGS_DIR}/log$( date +'%Y%m%d%H%M%S' ).txt"
    fi
    ls -t "${LOGS_DIR}"/log*.txt | tail -n +17 | while read -r LOGS_LOGFILE; do
        rm -vf "${LOGS_LOGFILE}"
    done
fi
touch "${LOG_FILE}"
chmod 704 "${LOG_FILE}"

rm -f "${STRASHBOT_USER_HOME}/${RACER_DIR}/ringdata.dat"

CFG_DIR="${STRASHBOT_USER_HOME}/${RACER_DIR}/cfg"
ADDONS_DIR="${STRASHBOT_USER_HOME}/${RACER_DIR}/addons"

CUSTOM_CFG_SCRIPT="${STRASHBOT_USER_HOME}/${RACER_DIR}/customyamlconfig_to_cfg.py"
OPERATOR_SCRIPT="${STRASHBOT_USER_HOME}/${RACER_DIR}/racer_operator.sh"

if [ -f "${CUSTOM_CFG_SCRIPT}" ]; then
    "${CUSTOM_CFG_SCRIPT}" "RESTORE_ADDONS" "${CFG_DIR}" "${ADDONS_DIR}"
fi  
"${OPERATOR_SCRIPT}" "PENDING" "force"
if [ -f "${CUSTOM_CFG_SCRIPT}" ]; then
    "${CUSTOM_CFG_SCRIPT}" "MAKE" "${CFG_DIR}" "${ADDONS_DIR}"
fi

LOAD_ORDER_SCRIPT="${STRASHBOT_USER_HOME}/${RACER_DIR}/load_addon_manager.py"

STATE_FILE="${STRASHBOT_USER_HOME}/${RACER_DIR}/state.txt"
MAPS_FILE="${STRASHBOT_USER_HOME}/${RACER_DIR}/maps.txt"
SKINS_FILE="${STRASHBOT_USER_HOME}/${RACER_DIR}/skins.txt"
touch "${STATE_FILE}" "${MAPS_FILE}" "${SKINS_FILE}" 
chmod 704 "${STATE_FILE}" "${MAPS_FILE}" "${SKINS_FILE}"

trap 'kill $(jobs -p)' EXIT
( tail -f "${LOG_FILE}" | "${STRASHBOT_USER_HOME}/${RACER_DIR}/log_processor.py" "${STATE_FILE}" "${MAPS_FILE}" "${SKINS_FILE}") &
nice -n -20 ${RACER_EXE} -dedicated -password ${PASS} ${RACER_LAUNCH_ARGS} \
    $( [ -f "${LOAD_ORDER_SCRIPT}" ] && "${LOAD_ORDER_SCRIPT}" --file_line --addons_dir "${ADDONS_DIR}/enabled" )
