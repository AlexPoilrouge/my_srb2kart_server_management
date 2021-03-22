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
depend_check "find"
depend_check "useradd"
depend_check "envsubst"
depend_check "srb2kart"




##### Obtaining variable values #####

VALUES_FILE="values.txt"


check_val(){
    if [ "${1+x}" = "" ]; then
        echoerr "Variable $1 not set…"
        false
    else
        true
    fi
}


VAR_SUBST=""
while read -r VAR_LINE; do
    if [[ "${VAR_LINE}" =~ ^[0-9a-zA-Z_]+\:.*$ ]]; then
        VAR="$( echo "${VAR_LINE}" | cut -d: -f1 )"
        VAL="$( echo "${VAR_LINE}" | cut -d: -f2- )"

        export VAR_SUBST="${VAR_SUBST} \\\$${VAR}"
    	
        if eval [ -x '${'"${VAR}"'+x}' ]; then
            echoerr "export \"${VAR}\"=\"${VAL}\""
            eval "export \"${VAR}\"=\"${VAL}\""
        else
            echoerr "[WARNING] Variable '${VAR}' was already set; ignoring value in '${VALUES_FILE}'"
            eval export "${VAR}"
    	fi
	if eval "[ \"\${${VAR}}\" = \"\" ]"; then
		echoerr "[WARNING] Variable '${VAR}' remains empty..."
	fi
    else
    	echoerr "[CRITICAL WARNING] In '${VALUES_FILE}', line '${VAR_LINE}' is invalid."
    fi
done < "${VALUES_FILE}"

if check_val "${NGINX_INSTALL}" && "${NGINX_INSTALL}"; then
    depend_check "nginx"
fi


##### Install 1 #####

if ! check_val "${STRASHBOT_USER}" || ! check_val "${SRB2KART_DIR}"; then
    echoerr "STRASHBOT_USER & SRB2KART_DIR need to be set…"
    exit 5
fi

if [ "$(grep -c "^${STRASHBOT_USER}:" /etc/passwd)" -eq 0 ]; then
    useradd -m "${STRASHBOT_USER}"
fi

export VAR_SUBST="${VAR_SUBST} \\\$STRASHBOT_USER_HOME"
if eval [ -x ${STRASHBOT_USER_HOME+x} ]; then
	export STRASHBOT_USER_HOME="$( realpath "$( eval echo ~"${STRASHBOT_USER}" )" )"
	echoerr "export \"STRASHBOT_USER_HOME\"=\"${STRASHBOT_USER_HOME}\""
else
	echoerr "[WARNING] Variable 'STRASHBOT_USER_HOME' was already set; ignoring value in '${STRASHBOT_USER_HOME}'"
	eval export "${STRASHBOT_USER_HOME}"
fi
if [ "${STRASHBOT_USER_HOME}" = "" ]; then
	echoerr "[WARNING] Variable '${STRASHBOT_USER_HOME}' remains empty..."
fi
SRB2KART_F_DIR="${STRASHBOT_USER_HOME}/${SRB2KART_DIR}"



##### Obtaining and formating files #####

check_template(){
    if ! [ -f "${1}.template" ]; then
        echoerr "Missing template file for $1 ( ${1}.template )"
        exit 4
    fi
}


convert_template(){
    echo -n "-- formatting '$1'"
    TEMPLATE_FILE="$1"
    if [[ "${TEMPLATE_FILE}" =~ .*\.template$ ]]; then
        TARGET_FILE="${TEMPLATE_FILE%.*}"
        check_template "${TARGET_FILE}"
        (eval "envsubst \"${VAR_SUBST}\"" ) < "${TEMPLATE_FILE}" > "${TARGET_FILE}"
        echo " -> ${TARGET_FILE}"
    else
        echo " -> ! ERROR !"
    fi
}
export -f check_template
export -f convert_template

find . -regex '.*\.template$' -exec bash -c 'convert_template {}' \;




##### Install 2 #####

if "${SYSTEMD_INSTALL}" && ( ! check_val "${SERVICE_INSTALL_PATH}" || ! check_val "${SUDOERS_DIR}" ); then
    depend_check "systemctl"
    
    echoerr "Need SERVICE_INSTALL_PATH & SUDOERS_DIR for systemd install";
    exit 6
fi

mkdir -p "${SRB2KART_F_DIR}"

install -v ./scripts/{ls_restricted.lib.sh,addon_script.sh,zipping_addons.sh,record_lmp_read.py,log_processor.py} "${SRB2KART_F_DIR}" -m 700
install -v ./config/serv/{dkartconfig.cfg,kartserv.cfg,server_start.sh} "${SRB2KART_F_DIR}" -m 700

mkdir -p "${ROOT_DIR}/etc/security/limits.d"
install -v ./config/10-strashbot-user-nice-limite.conf "${ROOT_DIR}/etc/security/limits.d" -m 644

#preventing override
if ! [ -f "${SRB2KART_F_DIR}/startup.cfg" ]; then
    install -v ./config/serv/startup.cfg "${SRB2KART_F_DIR}" -m 704
else
    chmod 704 "${SRB2KART_F_DIR}/startup.cfg"
fi
chown "${STRASHBOT_USER}:${STRASHBOT_USER}" -R "${SRB2KART_F_DIR}"

if "${SYSTEMD_INSTALL}"; then
    echo "Systemd install…"
    mkdir -p "${ROOT_DIR}/${SERVICE_INSTALL_PATH}"
    install -v config/{srb2kart_serv.service,strashbot_zip_addons.service} "${ROOT_DIR}/${SERVICE_INSTALL_PATH}" -m 644
    
    echo "[systemd] daemon reload…"
    systemctl daemon-reload

    mkdir -p "${ROOT_DIR}/${SUDOERS_DIR}"
    install -v config/10-strashbot-kartserv-systemd "${ROOT_DIR}/${SUDOERS_DIR}" -m 644
fi

if "${NGINX_INSTALL}"; then
    echo "Nginx install… ${NGINX_DIR}"

    chmod 701 "${STRASHBOT_USER_HOME}"

    mkdir -p "${ROOT_DIR}/${NGINX_DIR}/sites-available"
    mkdir -p "${ROOT_DIR}/${NGINX_DIR}/sites-enabled"

    install -v config/nginx-http-srb2kart.conf "${ROOT_DIR}/${NGINX_DIR}/sites-available" -m 644

    ln -sf "${ROOT_DIR}/${NGINX_DIR}/sites-available/nginx-http-srb2kart.conf" "${ROOT_DIR}/${NGINX_DIR}/sites-enabled/nginx-http-srb2kart.conf"

    echo -e "[IMPORTANT] Make sure the line \n\tinclude sites-enabled/*;\n is added to '${ROOT_DIR}/${NGINX_DIR}/nginx.conf''s 'http' block!"
    
    if "${SYSTEMD_INSTALL}" && ( systemctl is-active nginx.service >/dev/null 2>&1 ); then
        echo "[systemd] restarting nginx…"
        systemctl restart nginx.service
    fi
fi

su ${STRASHBOT_USER} -c "cd ${SRB2KART_F_DIR}; ./addon_script.sh INIT"

echo "End."
