#!/bin/bash

echoerr() { echo "$@" 1>&2; }

depend_check() {
    for arg; do
		hash "$arg" 2>/dev/null || { echoerr "Error: Could not find \"$arg\" application."; exit 2; }
    done    
}

SCRIPT_DIR="$( realpath "$( dirname "$0" )" )"

cd "$SCRIPT_DIR"

ROOT_DIR="/"
if [ "$#" -gt 0 ] && [ -d "$1" ]; then
    ROOT_DIR="$1"
fi

echo "Root dir is set to ${ROOT_DIR}"



if ! [ "$( id -u )" = 0 ]; then
   echo "$0 must be run with root privileges…"
   exit 1
fi

depend_check "sudo"
depend_check "git"
depend_check "make"
depend_check "ansible-playbook"
depend_check "yq"

ANSIBLE_DIR="${SCRIPT_DIR}/config/ansible"
VARIABLES_YAML="${ANSIBLE_DIR}/variables.yaml"

RACER_MANAGER_SCRIPT_BASENAME="racer_operator.sh"
RACER_MANAGER_SCRIPT_INIT_ARGS="INIT"


make -C "${ANSIBLE_DIR}" local_install LOCAL_SOURCE_DIR="${SCRIPT_DIR}"


STRASHBOT_USER="$( yq '.strashbot.username' "${VARIABLES_YAML}" | tr -d '"' )"
STRASHBOT_HOMEDIR="$( yq '.strashbot.home' "${VARIABLES_YAML}" | tr -d '"' )"

yq '.racers.[].dirname' "${VARIABLES_YAML}" | tr -d '"'  | while read RACER_DIRNAME; do
  RACER_DIR="${STRASHBOT_HOMEDIR}/${RACER_DIRNAME}"
  echo ">>> Init '${RACER_DIR}'"
  su ${STRASHBOT_USER} -c "cd ${RACER_DIR}; ./${RACER_MANAGER_SCRIPT_BASENAME} ${RACER_MANAGER_SCRIPT_INIT_ARGS}"
done

echo "End."
