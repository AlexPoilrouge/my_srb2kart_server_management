#!/bin/bash

SCRIPT_NAME="$( basename "$0" )"
SCRIPT_DIR="$( realpath "$( dirname "$0" )" )"

BUILD_USER="builduser"
SUDOER_LINE="${BUILD_USER} ALL=(ALL) ALL\n"
SUDOER_FILE="/etc/sudoers"

BASE_PKGBUILD_TAR_URL="https://aur.archlinux.org/cgit/aur.git/snapshot"

builduser_check(){
    if ! id "${BUILD_USER}"; then
        useradd "${BUILD_USER}" -m && passwd -d "${BUILD_USER}"
    fi

    #adding sudoer permission if necessary
    if ! ( cat "${SUDOER_FILE}" | grep "${SUDOER_LINE}" &> /dev/null ); then
        printf "${BUILD_USER} ALL=(ALL) ALL\n" | tee -a /etc/sudoers
    fi 
}

install_aur_pkg(){
    PKG_NAME="$1"

    _CUR_DIR="$( pwd )"

    # working in package dir
    mkdir -p "${SCRIPT_DIR}/packages"
    cd "${SCRIPT_DIR}/packages"

    #donwloading package from AUR
    wget "${BASE_PKGBUILD_TAR_URL}/${PKG_NAME}.tar.gz"

    #extracting downloaded tar.gz
    tar -xf "${PKG_NAME}.tar.gz"

    #need to be sure we can write to use 'makepkg'
    chmod -R 777 "${PKG_NAME}"

    #with fake user, launching makepkg
    sudo -u "${BUILD_USER}" bash -c "cd \"${PKG_NAME}\" && makepkg -s --noconfirm"

    #installing built package
    pacman -U "${PKG_NAME}/${PKG_NAME}"*".pkg.tar.zst" --noconfirm

    #cleaning up
    rm -rf "${PKG_NAME}.tar.gz" "${PKG_NAME}"

    #get out!
    cd "${_CUR_DIR}"
}


#making sure we have our built user
builduser_check

for arg in $@; do
    install_aur_pkg "${arg}"
done
