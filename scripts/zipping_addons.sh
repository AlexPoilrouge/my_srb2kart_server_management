#!/bin/bash

SCRIPT_DIR="$( dirname "$( realpath "$0" )" )"

source "${SCRIPT_DIR}/ls_restricted.lib.sh"

gen_addons_zip(){
    _WORK_DIR="$( realpath . )"
    if [ -n "$1" ] && [ -d "$1" ]; then
        _WORK_DIR="$1"
    fi

    _DL_ADDONS_DIR="${_WORK_DIR}/dl"
    _BASE_ADDONS_DIR="${_WORK_DIR}/Packs"
    _TMP_ZIP="${_WORK_DIR}/tmp_strashbot_addons.zip"
    _ZIP_ARCHIVE="${_WORK_DIR}/strashbot_addons.zip"
    _README="${_WORK_DIR}/README.txt"

    rm -f "${_TMP_ZIP}" 2>/dev/null 2>&1
    echo "These addons are to be copied in the 'DOWNLOAD' folder of your SRB2Kart folder…" > "${_README}"
    zip "${_TMP_ZIP}" -j "${_README}" >/dev/null 2>&1
    rm -f "${_README}" 2>/dev/null 2>&1

    ( ls_restricted "${_DL_ADDONS_DIR}" ) | while read -r L; do
        zip -jur "${_TMP_ZIP}" "${L}" >/dev/null 2>&1
    done;

    ( ls_restricted "${_BASE_ADDONS_DIR}" ) | while read -r L; do
        zip -jur "${_TMP_ZIP}" "${L}" >/dev/null 2>&1
    done;

    mv "${_TMP_ZIP}" "${_ZIP_ARCHIVE}"
}

gen_addons_zip "$1"
