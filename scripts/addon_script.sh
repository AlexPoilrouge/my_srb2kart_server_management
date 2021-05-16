#!/bin/bash

echoerr() { echo "$@" 1>&2; }

SCRIPT_DIR="$( dirname "$( realpath "$0" )" )"

PYTHON_LMP_ATTACK_SCRIPT="record_lmp_read.py"

PYTHON_CLIP_MANAGEMENT_SCRIPT="clip_manager.py"

PYTHON_LOAD_ADDON_MANAGER_SCRIPT="load_addon_manager.py"

PYTHON_PATH="/bin/python3"

SERV_SERVICE="srb2kart_serv.service"

source "${SCRIPT_DIR}/ls_restricted.lib.sh"

cd "${SCRIPT_DIR}"



TMP_FILE="tmp_load.cfg"
DL_FILE="dl_load.cfg"
BASE_FILE="base_load.cfg"

LUAFILES_DIR="luafiles"
MEMBERS_FILE="${LUAFILES_DIR}/members.txt"
WELCOME_FILE="${LUAFILES_DIR}/welcome.txt"

_STATE_FILE="state.txt"

ADDONS_DIR="addons"
PENDING_ADDONS_DIR="${ADDONS_DIR}/tmp"
INSTALLED_ADDONS_DIR="${ADDONS_DIR}/dl"
BASE_ADDONS_DIR="${ADDONS_DIR}/Packs"

TIME_MAPS_DIR="maps"

CLIP_DATA_DIR="${SCRIPT_DIR}/web/json"


_update(){
    _LOG_FILE="log.txt"
    if [ -f "${_LOG_FILE}" ]; then
        chmod 704 "${_LOG_FILE}"
    fi

    if [ -f "${_STATE_FILE}" ]; then
        chmod 704 "${_STATE_FILE}"
    fi


    echo "wait" > "${TMP_FILE}"
    ( ls_restricted "${PENDING_ADDONS_DIR}" ) | while read -r L; do
            chmod 704 "${L}"
            if ( ! systemctl is-active "${SERV_SERVICE}" >/dev/null 2>&1 ) || [ "$1" == "RESTARTING" ]; then
                mv "${L}" "${INSTALLED_ADDONS_DIR}"
            fi
        done


    if ! [ -f "${PYTHON_LOAD_ADDON_MANAGER_SCRIPT}" ]; then
        echo "wait" > "${DL_FILE}"
        ( ls_restricted "${INSTALLED_ADDONS_DIR}" ) | while read -r L; do
                chmod 704 "${L}"
                echo "addfile \"${L}\"" >> "${DL_FILE}"
                echo "wait" >> "${DL_FILE}"
            done
    else
        ${PYTHON_PATH} "${PYTHON_LOAD_ADDON_MANAGER_SCRIPT}" "${INSTALLED_ADDONS_DIR}"
    fi
    
    


    echo "wait" > "${BASE_FILE}"
    ( ls_restricted "${BASE_ADDONS_DIR}" ) | while read -r L; do
            chmod 704 "${L}"
            echo "addfile \"${L}\"" >> "${BASE_FILE}"
            echo "wait" >> "${BASE_FILE}"
        done

    sudo systemctl restart strashbot_zip_addons.service
}

CFG_CMD_BLACKLIST=("addfile" "alias" "bind" "toggle" "changeconfig" "exec" "loadconfig" "runsoc" "saveconfig" "exitgame" "quit" "demote" "password" "promote" "connect" "cheats" "runscripts" "addons_folder" "addons_option" "addons_search_case" "addons_search_type" "maxsend")

_filter_cfg_cmd(){
    for i in ${CFG_CMD_BLACKLIST[@]}; do
        echo "$( sed "s/^\s*${i}/\/\/${i}/g" "$1" )" > "$1"
    done
}

CMD="UPDATE"

if [ "$1" != "" ]; then
    CMD="$1"
fi

case "$CMD" in
"INIT")
    mkdir -p "${PENDING_ADDONS_DIR}"
    mkdir -p "${INSTALLED_ADDONS_DIR}"
    mkdir -p "${BASE_ADDONS_DIR}"

    mkdir -p "${TIME_MAPS_DIR}"

    touch "${_STATE_FILE}"
    chmod 704 "${_STATE_FILE}"

    _update
;;
"CLEAN")
    for i in ${EXTENSIONS[@]}; do
        rm -rvf tmp/*.${i} 2>/dev/null
    done
;;
"START_SERV")
    echo -e "{\"modes\": []}" > "${_STATE_FILE}"
    
    sudo systemctl start "${SERV_SERVICE}"
;;
"STOP_SERV")
    sudo systemctl stop "${SERV_SERVICE}"

    echo -e "{\"modes\": []}" > "${_STATE_FILE}"

    _update
;;
"RESTART_SERV")
    _update "RESTARTING"

    echo -e "{\"modes\": []}" > "${_STATE_FILE}"

    sudo systemctl restart "${SERV_SERVICE}"
;;
"IS_ACTIVE_SERV")
    if systemctl is-active "${SERV_SERVICE}" >/dev/null 2>&1; then
        echo "active"
        exit 0
    else
        echo "inactive"
        exit 1
    fi
;;
"INFO_SERV")
    if [ -f "${_STATE_FILE}" ]; then
        cat "${_STATE_FILE}"
    else
        exit 27
    fi
;;
"LIST")
    _TEST=false
    echo "**[Pending]**"
    _S=""
    _TMP="$( ( ls_restricted "${PENDING_ADDONS_DIR}" "$2" ) | while read -r L; do echo -n "${_S}$( basename "${L}" )"; _S=" ";_TEST=true; done )"
    if [ "${_TMP}" != "" ]; then _TEST=true; fi
    echo "${_TMP}"
    echo "**[Downloaded]**"
    _S=""
    _TMP="$( ( ls_restricted ${INSTALLED_ADDONS_DIR} "$2" ) | while read -r L; do echo -n "${_S}$( basename "${L}" )"; _S=" ";_TEST=true; done )"
    if [ "${_TMP}" != "" ]; then _TEST=true; fi
    echo "${_TMP}"
    echo "**[Base]**"
    _S=""
    _TMP="$( ( ls_restricted ${BASE_ADDONS_DIR} "$2" ) | while read -r L; do echo -n "${_S}$( basename "${L}" )"; _S=" ";_TEST=true; done )"
    if [ "${_TMP}" != "" ]; then _TEST=true; fi
    echo "${_TMP}"
    
    if ! "${_TEST}"; then exit 3; fi
;;
"ADD_FILE")
    if [ $# -lt 2 ]; then
        echo "Needs file…"
        exit 42
    fi

    SRC_FILE="$2"
    if ! [ -f "${SRC_FILE}" ]; then
        echo "Needs existing file…"
        exit 43
    fi

    DEST_DIR="${INSTALLED_ADDONS_DIR}"
    if systemctl is-active "${SERV_SERVICE}" >/dev/null 2>&1; then
        DEST_DIR="${PENDING_ADDONS_DIR}"
    fi

    _TEST=false
    for ext in ${EXTENSIONS[@]}; do
        if [[ "${SRC_FILE}" =~ ^.*\."${ext}"$ ]]; then export _TEST=true; fi
    done

    if ${_TEST}; then
        cp -rvf "${SRC_FILE}" "${DEST_DIR}/$( basename ${SRC_FILE} )"
        echo "DONE"
    else
        echo "ERROR - bad format"
        exit 23
    fi
;;
"ADD_URL")
    if [ $# -lt 2 ]; then
        echo "Needs url…"
        exit 24
    fi

    DEST_DIR="${INSTALLED_ADDONS_DIR}"
    if systemctl is-active "${SERV_SERVICE}" >/dev/null 2>&1; then
        DEST_DIR="${PENDING_ADDONS_DIR}"
    fi

    _TEST=false
    for ext in ${EXTENSIONS[@]}; do
        if [[ "$2" =~ ^https?\:\/\/(w{0,3}\.)?[a-zA-Z0-9\.\/\@\_\-]*\."${ext}"$ ]]; then export _TEST=true; fi
    done

    if ${_TEST}; then
        wget -O "${DEST_DIR}/${2##*/}" --progress=dot "$2" 2>&1 | grep --line-buffered "%" | \
            sed -u -e "s,\.,,g" | awk '{printf("%4s\n", $2)}'
        echo "DONE"
    else
        echo "ERROR - bad format"
        exit 23
    fi
;;
"REMOVE")
    if [ $# -ge 2 ]; then
        _DIR="$( realpath "$( dirname "$2" )" )"
        if [ "${_DIR}" = "${INSTALLED_ADDONS_DIR}" ] || [ "${_DIR}" = "${PENDING_ADDONS_DIR}" ]; then
            if _RES="$( rm -v $2 2>/dev/null )"; then
                echo "$_RES"
            else
                echo "Unable to delete such file: \`$2\`…"
                exit 2
            fi
        elif _RES="$( ( rm -v "${PENDING_ADDONS_DIR}/$2" || rm -v "${INSTALLED_ADDONS_DIR}/$2" ) 2>/dev/null )"; then
            echo "$_RES"
        elif _RES="$( [ "$( realpath "$( dirname "${ADDONS_DIR}/$2" )" )" != "${BASE_ADDONS_DIR}" ] && ( rm -v "${ADDONS_DIR}/$2" 2>/dev/null ) )"; then
            echo "$_RES"
        else
            echo "Unable to delete such file: \`$2\`…"
            exit 2
        fi
    else
        echo "No given file to delete…"
        exit 2
    fi
;;
"KEEP")
    if [ $# -lt 2 ]; then
        echo "No addon given…"
        exit 4
    fi

    _DIR="tmp"
    _FILE="tmp/$2"
    if [ "$(dirname "$2" )" = "tmp" ]; then
        _FILE="tmp/$( basename "$2" )"
    fi

    if mv "$_FILE" "${INSTALLED_ADDONS_DIR}/$( basename $2 )"; then
        _update
        echo "$( basename $2 ) moved from **[Temporary]** to **[Downloaded]**"
    else
        echo "Unable to move such **[Temporary]** addon *$2*…"
        exit 5
    fi
;;
"GET_CONFIG")
    _CFG_FILE="startup.cfg"
    if [ -f "$_CFG_FILE" ]; then
        echo -n "$_CFG_FILE"
    else
        exit 6
    fi
;;
"ADD_CONFIG_URL")
    if [ $# -lt 2 ]; then
        echo "Needs url…"
        exit 25
    fi

    DL_FILE="new_startup.cfg"
    if [[ "$2" =~ ^https?\:\/\/(w{0,3}\.)?[a-zA-Z0-9\.\/\@\_\-]*\.cfg$ ]]; then
        wget -O "${DL_FILE}" --progress=dot $2 2>&1 | grep --line-buffered "%" | \
            sed -u -e "s,\.,,g" | awk '{printf("%4s\n", $2)}'
        echo "DONE - ${DL_FILE}"
    else
        echo "ERROR - bad format"
        exit 22
    fi
;;
"CHANGE_CONFIG")
    if [ $# -lt 2 ]; then
        echo "No new .cfg given for update…"
        exit 7
    fi

    _CFG_FILE="startup.cfg"
    
    if ! [ -f "${2}" ]; then
        echo "Given .cfg ($2) doesn't seem to be a valid path…"
        exit 7
    fi

    _filter_cfg_cmd "$2"

    _DIFF_FILE="startup.cfg.diff"

    if [ -f "${_CFG_FILE}" ]; then
        diff -u "${_CFG_FILE}" "$2" > "${_DIFF_FILE}"

        echo -n "$( realpath ${_DIFF_FILE} )"
    else
        echo -n "updated"
    fi

    mv "${2}" "${_CFG_FILE}"
    chmod 704 "${_CFG_FILE}"
;;
"GET_ADDON_ORDER_CONFIG")
    _AOC_FILE="addon_load_order.txt"
    if [ -f "$_AOC_FILE" ]; then
        echo -n "$_AOC_FILE"
    else
        exit 44
    fi
;;
"ADD_ADDON_ORDER_CONFIG_URL")
    if [ $# -lt 2 ]; then
        echo "Needs url…"
        exit 46
    fi

    DL_FILE="new_addon_load_order.txt"
    if [[ "$2" =~ ^https?\:\/\/(w{0,3}\.)?[a-zA-Z0-9\.\/\@\_\-]*$ ]]; then
        wget -O "${DL_FILE}" --progress=dot $2 2>&1 | grep --line-buffered "%" | \
            sed -u -e "s,\.,,g" | awk '{printf("%4s\n", $2)}'
        echo "DONE - ${DL_FILE}"
    else
        echo "ERROR - bad format"
        exit 47
    fi
;;
"CHANGE_ADDON_ORDER_CONFIG")
    if [ $# -lt 2 ]; then
        echo "No new file given for update…"
        exit 45
    fi

    _AOC_FILE="addon_load_order.txt"
    
    if ! [ -f "${2}" ]; then
        echo "Given file ($2) doesn't seem to be a valid path…"
        exit 48
    fi
    
    _DIFF_FILE="startup.cfg.diff"

    if [ -f "${_AOC_FILE}" ]; then
        diff -u "${_AOC_FILE}" "$2" > "${_DIFF_FILE}"

        echo -n "$( realpath ${_DIFF_FILE} )"
    else
        echo -n "updated"
    fi

    mv "${2}" "${_AOC_FILE}"
    chmod 704 "${_AOC_FILE}"    
;;
"CFG_BLACKLIST")
    for i in ${CFG_CMD_BLACKLIST[@]}; do
        echo -n "\`$i\` "
    done
    echo ""
;;
"GET_LOG")
    _LOG_FILE="log.txt"
    if [ -f "${_LOG_FILE}" ]; then
        chmod 704 "${_LOG_FILE}"
        echo -n "${_LOG_FILE}"
    else
        exit 8
    fi
;;
"RECORD_MAPS")
    if ! [ -f "${PYTHON_LMP_ATTACK_SCRIPT}" ]; then
        echo "ERROR - internal error (no lmp eval func)"
        exit 9
    fi

    PATTERN=""
    LISTING=true
    if [ "$#" -gt 1 ]; then
        MAPNAME="$( _I=0; for _E in $@; do if [ "$_I" -gt 1 ]; then echo -n " "; fi ; if [ "$_I" -gt 0 ]; then echo -n "$_E"; fi; ((_I++)); done )"
        MAP_DIR="$( echo ${MAPNAME// /_} | tr '[:lower:]' '[:upper:]' )"
        NB_MATCH="$( ls -d1 "${TIME_MAPS_DIR}"/*/ 2>/dev/null | grep -i "${MAP_DIR}" | wc -l )"
        if ! [ -d "${TIME_MAPS_DIR}/$2" ] && [  "${NB_MATCH}" -gt 1 ]; then
            PATTERN="$2"
        elif [ "${NB_MATCH}" -eq 1 ]; then
            LISTING=false
        else
            echo "ERROR - No matching match found for records…"
            exit 10
        fi    
    fi

    if ${LISTING}; then
        if ! [ -d "${TIME_MAPS_DIR}" ]; then
            mkdir -p "${TIME_MAPS_DIR}"
        fi 
        
        ( ( if [ "$PATTERN" != "" ]; then ls -d1 "${TIME_MAPS_DIR}"/*/ 2>/dev/null | grep -i "${PATTERN}"; else ls -d1 "${TIME_MAPS_DIR}"/*/ 2>/dev/null; fi ) \
                | eval "sed \"s/^${TIME_MAPS_DIR/\//\\\/}//\"" | sed 's/\///g'
           ) | while read -r L; do
            RECORD="\`no record\`"
            if [ -f "${TIME_MAPS_DIR}/${L}/record.txt" ]; then
                RECORD="$( sed '2q;d' "${TIME_MAPS_DIR}/${L}/record.txt" )"
                if [ "$RECORD" == "" ]; then
                    RECORD="\`no record\`"
                fi
            fi
            echo "${L} - **record:** ${RECORD} - $( (ls -1 "${TIME_MAPS_DIR}/${L}/"*.lmp 2>/dev/null ) | wc -l ) times"
        done

        exit 0
    else
        echo "=== ${MAP_DIR} ==="
        ( ${PYTHON_PATH} "${PYTHON_LMP_ATTACK_SCRIPT}" "${TIME_MAPS_DIR}/${MAP_DIR}" | tr '\0' ' ' ) |  while read -r REC; do
            REC="${REC// /_}"
            REC_TAB=(${REC//::::/ })

            if [ "${REC_TAB[0]}" == "" ]; then
                echo "ERROR"
            else
                echo "${REC_TAB[0]} - ${REC_TAB[1]//_/ }"
                if [ "${REC_TAB[0]}" == "SUCCESS" ]; then
                    #echo "${REC_TAB[2]//_/ }"
                    echo "${REC_TAB[13]}"
                    echo "${REC_TAB[7]}"
                    echo "${REC_TAB[8]}"
                    _CHARACTER="${REC_TAB[9]}"
                    echo -n "$( echo ${_CHARACTER:0:1} | tr '[:lower:]' '[:upper:]' )$( echo ${_CHARACTER:1} )"
                    echo " ($( echo "${REC_TAB[10]}" | tr '[:upper:]' '[:lower:]' ))"
                    echo "${REC_TAB[11]} ${REC_TAB[12]}"
                    echo "SRB2Kart ${REC_TAB[3]}"
                    _NB_ADDONS="${REC_TAB[4]}"
                    echo -n "[ ${_NB_ADDONS} ]"
                    if [ "${_NB_ADDONS}" -gt 0 ]; then
                        echo "${REC_TAB[5]}" | tr ';' ' '
                    else
                        echo ""
                    fi
                fi
            fi
            echo "---"
        done
        exit 0
    fi
;;
"ADD_RECORD_URL")
    if [ $# -lt 3 ]; then
        echo "Needs url and id…"
        exit 26
    fi

    if [[ "$2" =~ ^https?\:\/\/(w{0,3}\.)?[a-zA-Z0-9\.\/\@\_\-]*\.lmp$ ]]; then
        wget -O "${3%.lmp}.lmp" --progress=dot "$2" 2>&1 | grep --line-buffered "%" | \
            sed -u -e "s,\.,,g" | awk '{printf("%4s\n", $2)}'
        echo "DONE - ${DL_FILE}"
    else
        echo "ERROR - bad format"
        exit 24
    fi
;;
"ADD_RECORD")
    if [ "$#" -lt 2 ]; then
        echo "ERROR - File map not provided"
        exit 11
    elif ! [ -f "$2" ]; then
        echo "ERROR - Non existing file map"
        exit 12
    elif [ "$#" -lt 3 ]; then
        echo "ERROR - Need to provided a tag for file renaming"
        exit 13
    fi

    REC="$( ${PYTHON_PATH} "${PYTHON_LMP_ATTACK_SCRIPT}" "$2" )"
    REC_TAB=(${REC//::::/ })

    if [ "${REC_TAB[0]}" != "SUCCESS" ]; then
        echo "${REC_TAB[0]} - ${REC_TAB[1]}"
        exit 14
    elif [ "${REC_TAB[7]}" == "unfinished" ]; then
        echo "ERROR - Will only add completed track runs…"
        exit 15
    fi

    MAP_DIR="${REC_TAB[2]// /_}"
    mkdir -p "${TIME_MAPS_DIR}/${MAP_DIR}"

    if ! mv "${2}" "${TIME_MAPS_DIR}/${MAP_DIR}/$3.lmp"; then
        echo "ERROR - Can't add .lmp file"
        exit 16
    fi

    _RECORD_FILE="${TIME_MAPS_DIR}/${MAP_DIR}/record.txt"
    if ! [ -f "${_RECORD_FILE}" ] || [ "$( sed '1q;d' "${_RECORD_FILE}" )" -gt "${REC_TAB[6]}" ]; then
            echoerr "### ${_RECORD_FILE}"
            echo "${REC_TAB[6]}" > "${_RECORD_FILE}"
            echo "${REC_TAB[7]} by ${REC_TAB[8]} from $3" >> "${_RECORD_FILE}"

            echo "ADDED - New record! ${REC_TAB[7]}"
    else
        echo "ADDED - Record held: $( sed '2q;d' "${_RECORD_FILE}" )"
    fi

    exit 0
;;
"RECORD_GET")
    if [ "$#" -lt 2 ]; then
        echo "ERROR - Need  mapname"
        exit 17
    fi

    MAPNAME="$( _I=0; for _E in $@; do if [ "$_I" -gt 1 ]; then echo -n " "; fi ; if [ "$_I" -gt 0 ]; then echo -n "$_E"; fi; ((_I++)); done )"
    MAP_DIR="$( echo ${MAPNAME// /_} | tr '[:lower:]' '[:upper:]' )"

    if ! [ -d "${TIME_MAPS_DIR}/${MAP_DIR}" ] || [ "$( ls -1  "${TIME_MAPS_DIR}/${MAP_DIR}/"*.lmp 2>/dev/null | wc -l )" -lt 1 ]; then
        echo "ERROR - Can't find requested record…"
        exit 18
    fi

    _TMP="$( ls "${TIME_MAPS_DIR}/${MAP_DIR}/"*.lmp 2>/dev/null | grep -m1 .lmp )"
    _TMP="$( ${PYTHON_PATH} "${PYTHON_LMP_ATTACK_SCRIPT}" "${_TMP}")"
    _TMP=(${_TMP//::::/ })
    _TMP="${_TMP[14]}"
    echo "To challenge a ghost from this archives, copy the .lmp file into the subfolder /replay/kart of your srb2kart folder,\
and rename the file '${_TMP}-guest.lmp'."        > README.txt
    _ZIP="${TIME_MAPS_DIR}/${MAP_DIR}/${MAP_DIR}_record.zip"
    rm -rf "${_ZIP}" 2>/dev/null
    zip "${_ZIP}" README.txt >/dev/null 2>&1

    _C=0
    ( ls -1  "${TIME_MAPS_DIR}/${MAP_DIR}/"*.lmp 2>/dev/null ) |  while read -r F; do
        _PF="$( realpath "${F}" )"
        REC="$( ${PYTHON_PATH} "${PYTHON_LMP_ATTACK_SCRIPT}" "${_PF}" | tr '\0' ' ' )"
        REC="${REC// /_}"
        REC_TAB=(${REC//::::/ })

        _RECORD_FILE="${TIME_MAPS_DIR}/${MAP_DIR}/record.txt"
        NEW_NAME="${REC_TAB[14]}-guest-${REC_TAB[8]}"
        if [ -f "${_RECORD_FILE}" ] && [ "${REC_TAB[6]}" -eq "$( sed '1q;d' "${_RECORD_FILE}" )" ]; then
            NEW_NAME="${NEW_NAME}-BEST"
        fi
        NEW_NAME="${NEW_NAME}.lmp"

        cp "${_PF}" "${NEW_NAME}"
        zip -ur "${_ZIP}" "${NEW_NAME}" >/dev/null 2>&1
        rm -f "${NEW_NAME}"

        ((_C++))
    done

    echo "ZIPPED - ${_ZIP}"
    exit 0
;;
"RECORD_RM")
    if [ "$#" -lt 3 ]; then
        echo "ERROR - Need player tagname and mapname"
        exit 19
    fi

    TAGNAME="$2"
    MAPNAME="$( _I=0; for _E in $@; do if [ "$_I" -gt 2 ]; then echo -n " "; fi ; if [ "$_I" -gt 1 ]; then echo -n "$_E"; fi; ((_I++)); done )"
    MAP_DIR="$( echo ${MAPNAME// /_} | tr '[:lower:]' '[:upper:]' )"

    if ! [ -f "${TIME_MAPS_DIR}/${MAP_DIR}/${TAGNAME}.lmp" ]; then
        echo "ERROR - Can't find requested record…"
        exit 20
    fi

    if ! rm -f "${TIME_MAPS_DIR}/${MAP_DIR}/${TAGNAME}.lmp"; then
        echo "ERROR - Can't remove record…"
        exit 21
    fi

    if [ "$( (ls -1  "${TIME_MAPS_DIR}/${MAP_DIR}/"*.lmp 2>/dev/null) | wc -l )" -le 0 ]; then
        rm -rf "${TIME_MAPS_DIR}/${MAP_DIR}"
    else
        _C=0
        ( ls -1  "${TIME_MAPS_DIR}/${MAP_DIR}/"*.lmp 2>/dev/null ) |  while read -r F; do
            _PF="$( realpath "${F}" )"
            REC=$( ${PYTHON_PATH} "${PYTHON_LMP_ATTACK_SCRIPT}" "${_PF}" | tr '\0' ' ' )
            REC="${REC// /_}"
            REC_TAB=(${REC//::::/ })
            T_REC=4294967295

            if [ "${REC_TAB[0]}" == "SUCCESS" ]; then
                if [ "${REC_TAB[6]}" -lt "${T_REC}" ]; then
                    _RECORD_FILE="${TIME_MAPS_DIR}/${MAP_DIR}/record.txt"
                    T_REC="${REC_TAB[6]}"
                    echo "${T_REC}" > "${_RECORD_FILE}"
                    _BF="$( basename "${F}" )"
                    echo "${REC_TAB[7]} by ${REC_TAB[8]} from ${_BF%.lmp}" >> "${TIME_MAPS_DIR}/${MAP_DIR}/record.txt"
                fi
                ((_C++))
            fi
        done
        if [ "${_C}" -lt 0 ]; then
            rm -rf "${TIME_MAPS_DIR}/${MAP_DIR}"
        fi
    fi

    echo "RECORD_REMOVED - done"
    exit 0
;;
"REGISTER")
    if [ "$#" -lt 2 ]; then
        echo "ERROR - Need Discord id"
        exit 28
    fi

    DISCORD_ID="$2"

    mkdir -p "${LUAFILES_DIR}"
    touch "${MEMBERS_FILE}"
    touch "${WELCOME_FILE}"
    NUM_AND_LINE="$(grep -n "${DISCORD_ID}" "${MEMBERS_FILE}"  2>/dev/null | head -n 1)"
    LINE_INFOS="$(echo ${NUM_AND_LINE} | cut -d: -f2-)"
    NUM_LINE="$(echo ${NUM_AND_LINE}  | cut -d: -f1)"
    NEW_TOKEN="$( </dev/urandom tr -dc '0123456789azertyuiopqsdfghjklmwxcvbnAZERTYUIOPQSDFGHJKLMWXCVBN' | head -c8 )"
    WELCOME_TOKEN="$( </dev/urandom tr -dc '0123456789azertyuiopqsdfghjklmwxcvbnAZERTYUIOPQSDFGHJKLMWXCVBN' | head -c4 ):$( </dev/urandom tr -dc '0123456789azertyuiopqsdfghjklmwxcvbnAZERTYUIOPQSDFGHJKLMWXCVBN' | head -c4 )"

    if [ -z "${NUM_LINE}" ]; then
        echo "${NEW_TOKEN};0;${DISCORD_ID};$(echo "${WELCOME_TOKEN}" | cut -d: -f1)" >> "${MEMBERS_FILE}"
        echo "${WELCOME_TOKEN}" >> "${WELCOME_FILE}"

        echo "NEW_MEMBER ${NEW_TOKEN} ${WELCOME_TOKEN}"
    else
        SCORE="$(echo "${LINE_INFOS}" | cut -d';' -f2)"
        OLD_WELCOME1="$(echo "${LINE_INFOS}" | cut -d';' -f4 | cut -d: -f1)"
        
        sed -i "${NUM_LINE}s/.*/${NEW_TOKEN};${SCORE};${DISCORD_ID};$(echo "${WELCOME_TOKEN}" | cut -d: -f1)/" "${MEMBERS_FILE}"

        WELCOME_NUM_LINE="$(grep -n "${OLD_WELCOME1}" "${WELCOME_FILE}"  2>/dev/null | head -n 1 | cut -d: -f1)"
        sed -i "${WELCOME_NUM_LINE}s/.*/${WELCOME_TOKEN}/" "${WELCOME_FILE}"

        echo "CHANGE_MEMBER ${NEW_TOKEN} ${WELCOME_TOKEN}"
    fi

    exit 0
;;
"IS_REGISTERED")
    if [ "$#" -lt 2 ]; then
        echo "ERROR - Need Discord id"
        exit 29
    fi

    DISCORD_ID="$2"

    TOKEN="$(grep "${DISCORD_ID}" "${MEMBERS_FILE}"  2>/dev/null | cut -d';' -f1 )"

    if [ -z "${TOKEN}" ]; then
        echo "UNREGISTERED"
    else
        echo "REGISTERED"
    fi

    exit 0
;;
"CLEAR_SCORE")
    if [ "$#" -lt 2 ]; then
        mkdir -p "${LUAFILES_DIR}"
        touch "${MEMBERS_FILE}"
        touch "${MEMBERS_FILE}_"
        while read L; do
            DISCORD_ID="$(echo "$L" | cut -d';' -f3)"
            TOKEN="$(echo "$L" | cut -d';' -f1)"
            WELCOME1="$(echo "$L" | cut -d';' -f4)"
            echo "${TOKEN};0;${DISCORD_ID};${WELCOME1}" >> "${MEMBERS_FILE}_"
        done < "${MEMBERS_FILE}"

        mv "${MEMBERS_FILE}_" "${MEMBERS_FILE}"

        echo "SCORES_CLEARED"

        exit 0
    else
        DISCORD_ID="$2"

        touch "${MEMBERS_FILE}"
        LINE="$(grep "${DISCORD_ID}" "${MEMBERS_FILE}" 2>/dev/null)"

        if [ -z "${LINE}" ]; then
            echo "UNREGISTERED_MEMBER"
            exit 30
        fi
        TOKEN="$(echo "${LINE}" | cut -d';' -f1)"
        WELCOME1="$(echo "${LINE}" | cut -d';' -f4)"

        sed -i "${NUM_LINE}s/.*/${TOKEN};0;${DISCORD_ID};${WELCOME1}/" ${MEMBERS_FILE}

        echo "INDIVIDUAL_SCORE_CLEARED"

        exit 0
    fi
;;
"CLIP_ADD")
    if [ "$#" -lt 2 ]; then
        echo "ERROR - clip url not provided"
        exit 0
        #exit 31
    elif [ "$#" -lt 3 ]; then
        echo "ERROR - user id not provided"
        exit 0
        #exit 32
    fi
    mkdir -p "${CLIP_DATA_DIR}"

    CLIP_URL="$2"
    CLIP_USER_ID="$3"
    CLIP_DESCRIPTION="$4"

    CLIP_PROCESS="$( ${PYTHON_PATH} "${PYTHON_CLIP_MANAGEMENT_SCRIPT}" "${CLIP_DATA_DIR}" ADD "${CLIP_URL}" ${CLIP_USER_ID} ${CLIP_DESCRIPTION} 2>/dev/null )"
    if [ -n "${CLIP_PROCESS}" ]; then
        readarray -t CLIP_TAB <<< "$( echo "${CLIP_PROCESS}" | sed -z 's/::::/\n/g' )"

        case "${CLIP_TAB[0]}" in
        "UNSUPPORTED_TYPE")
            echo "BAD_TYPE - ${CLIP_TAB[1]}"
            exit 0
            #exit 33
            ;;
        "ALREADY_IN_DATABASE")
            echo "ALREADY_ADDED - ${CLIP_TAB[2]}"
            exit 0
            #exit 35
            ;;
        "ERROR")
            echo "ERROR - ${CLIP_TAB[1]}"
            exit 0
            #exit 37
            ;;
        "CLIP_ADDED")
            echo "CLIP_ADDED - ${CLIP_TAB[1]}"
            exit 0
            ;;
        *)
            echo "UNKOWN_ERROR - ${CLIP_TAB[1]}"
            exit 0
            #exit 38
            ;;
        esac
    else
        echo "UNKOWN_ERROR - bad response"
        exit 0
        #exit 38
    fi
;;
"CLIP_RM")
    if [ "$#" -lt 2 ]; then
        echo "ERROR - clip id not provided"
        exit 0
        #exit 39
    elif [ "$#" -lt 3 ]; then
        echo "ERROR - user id not provided"
        exit 0
        #exit 32
    fi
    mkdir -p "${CLIP_DATA_DIR}"

    CLIP_ID="$2"
    CLIP_USER_ID="$3"

    CLIP_PROCESS="$( ${PYTHON_PATH} "${PYTHON_CLIP_MANAGEMENT_SCRIPT}" "${CLIP_DATA_DIR}" RM "${CLIP_ID}" ${CLIP_USER_ID} 2>/dev/null )"
    if [ -n "${CLIP_PROCESS}" ]; then
        readarray -t CLIP_TAB <<< "$( echo "${CLIP_PROCESS}" | sed -z 's/::::/\n/g' )"
        case "${CLIP_TAB[0]}" in
        "BAD_USER")
            echo "BAD_USER_ID - ${CLIP_TAB[1]}"
            exit 0
            #exit 34
            ;;
        "NO_SUCH_CLIP")
            echo "CLIP_NOT_FOUND - ${CLIP_TAB[1]}"
            exit 0
            #exit 36
            ;;
        "ERROR")
            echo "ERROR - ${CLIP_TAB[1]}"
            exit 0
            #exit 37
            ;;
        "CLIP_REMOVED")
            echo "CLIP_REMOVED"
            exit 0
            ;;
        *)
            echo "UNKOWN_ERROR - ${CLIP_TAB[1]}"
            exit 0
            #exit 38
        esac
    else
        echo "UNKOWN_ERROR - bad response"
        exit 0
        #exit 38
    fi
;;
"CLIP_CHECK")
    mkdir -p "${CLIP_DATA_DIR}"
    CLIP_PROCESS="$( ${PYTHON_PATH} "${PYTHON_CLIP_MANAGEMENT_SCRIPT}" "${CLIP_DATA_DIR}" CHECK 2>/dev/null )"
    if [ -n "${CLIP_PROCESS}" ]; then
        readarray -t CLIP_TAB <<< "$( echo "${CLIP_PROCESS}" | sed -z 's/::::/\n/g' )"
        case "${CLIP_TAB[0]}" in
        "ERROR")
            echo "ERROR - ${CLIP_TAB[1]}"
            exit 0
            #exit 37
            ;;
        "CLIPS_CHECKED")
            echo "CLIPS_CHECKED"
            exit 0
            ;;
        *)
            echo "UNKOWN_ERROR - ${CLIP_TAB[1]}"
            exit 0
            #exit 38
        esac
    else
        echo "UNKOWN_ERROR - ${CLIP_TAB[1]}"
        exit 0
        #exit 38
    fi
;;
"CLIP_INFO")
    if [ "$#" -lt 2 ]; then
        echo "ERROR - clip id not provided"
        exit 0
            #exit 39
    fi
    mkdir -p "${CLIP_DATA_DIR}"

    CLIP_ID="$2"
    CLIP_PROCESS="$( ${PYTHON_PATH} "${PYTHON_CLIP_MANAGEMENT_SCRIPT}" "${CLIP_DATA_DIR}" CLIP_INFO "${CLIP_ID}" 2>/dev/null )"
    if [ -n "${CLIP_PROCESS}" ]; then
        readarray -t CLIP_TAB <<< "$( echo "${CLIP_PROCESS}" | sed -z 's/::::/\n/g' )"
        case "${CLIP_TAB[0]}" in
        "ERROR")
            echo "ERROR - ${CLIP_TAB[1]}"
            exit 0
            #exit 37
            ;;
        "NO_SUCH_CLIP")
            echo "CLIP_NOT_FOUND - ${CLIP_TAB[1]}"
            exit 0
            #exit 36
            ;;
        "CLIP_INFO")
            if [ "${#CLIP_TAB[@]}" -lt 7 ]; then
                echo "UNEXPECTED_RESULT - ${CLIP_TAB[@]}"
                exit 0
                #exit 40
            fi

            AVAILABILITY="REACHABLE"
            if [ "${CLIP_TAB[6]}" -ge 1 ]; then
                AVAILABILITY="OUTDATED"
            fi

            echo "CLIP_INFO - ${CLIP_TAB[1]} - ${CLIP_TAB[2]} - ${CLIP_TAB[3]} - ${CLIP_TAB[4]} - ${CLIP_TAB[5]} - ${AVAILABILITY}"
            exit 0
            ;;
        *)
            echo "UNKOWN_ERROR - ${CLIP_TAB[1]}"
            exit 0
            #exit 38
        esac
    else
        echo "UNKOWN_ERROR - bad response"
        exit 0
        #exit 38
    fi
;;
"OUTDATED_CLIPS")
    mkdir -p "${CLIP_DATA_DIR}"

    CLIP_PROCESS="$( ${PYTHON_PATH} "${PYTHON_CLIP_MANAGEMENT_SCRIPT}" "${CLIP_DATA_DIR}" OUTDATED_CLIPS 2>/dev/null )"
    if [ -n "${CLIP_PROCESS}" ]; then
        readarray -t CLIP_TAB <<< "$( echo "${CLIP_PROCESS}" | sed -z 's/::::/\n/g' )"
        case "${CLIP_TAB[0]}" in
        "ERROR")
            echo "ERROR - ${CLIP_TAB[1]}"
            exit 0
            #exit 37
            ;;
        "OUTDATED_CLIPS")
            if [ "${#CLIP_TAB[@]}" -lt 2 ]; then
                echo "UNEXPECTED_RESULT - ${CLIP_TAB[@]}"
                exit 0
                #exit 40
            fi

            echo "OUTDATED_CLIPS - ${CLIP_TAB[1]} - ${CLIP_TAB[2]}"
            exit 0
        ;;
        *)
            echo "UNKOWN_ERROR - ${CLIP_TAB[1]}"
            exit 0
            #exit 38
        esac
    else
        echo "UNKOWN_ERROR - ${CLIP_TAB[1]}"
        exit 0
        #exit 38
    fi
;;
"EDIT_DESCRIPTION")
    if [ "$#" -lt 2 ]; then
        echo "ERROR - clip id not provided"
        exit 0
        #exit 39
    elif [ "$#" -lt 3 ]; then
        echo "ERROR - user id not provided"
        exit 0
        #exit 32
    fi
    mkdir -p "${CLIP_DATA_DIR}"

    CLIP_ID="$2"
    USER_ID="$3"
    CLIP_PROCESS="$( ${PYTHON_PATH} "${PYTHON_CLIP_MANAGEMENT_SCRIPT}" "${CLIP_DATA_DIR}" EDIT_DESCRIPTION "${CLIP_ID}" "${USER_ID}" "$4" 2>/dev/null )"
    if [ -n "${CLIP_PROCESS}" ]; then
        readarray -t CLIP_TAB <<< "$( echo "${CLIP_PROCESS}" | sed -z 's/::::/\n/g' )"
        case "${CLIP_TAB[0]}" in
        "BAD_USER")
            echo "BAD_USER_ID - ${CLIP_TAB[1]}"
            exit 0
            #exit 34
            ;;
        "ERROR")
            echo "ERROR - ${CLIP_TAB[1]}"
            exit 0
            #exit 37
            ;;
        "NO_SUCH_CLIP")
            echo "CLIP_NOT_FOUND - ${CLIP_TAB[1]}"
            exit 0
            #exit 36
            ;;
        "DESCRIPTION_UPDATED")
            echo "DESCRIPTION_UPDATED"
            exit 0
            ;;
        *)
            echo "UNKOWN_ERROR - ${CLIP_TAB[1]}"
            exit 0
            #exit 38
        esac
    else
        echo "UNKOWN_ERROR - ${CLIP_TAB[1]}"
        exit 0
        #exit 38
    fi
;;
"UPDATE")
    _update
;;
*)
        echo "ERROR - Invalid $0 command…"
        exit 255
;;
esac

exit 0
