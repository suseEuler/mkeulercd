#!/bin/bash
set -e

CUR_DIR=$(dirname $(readlink -f "$0"))
ARCH_ROOTFS_DIR=
ARCH_BOOTLOADER_DIR=
COMMON_ROOTFS_DIR=

ISO_ARCH=
ISO_SOURCE=
ISO_OUTPUT=
ISO_VOLID=

ACTION=
STAGE=

if [[ ! -e ${CUR_DIR}/.stage ]]; then
	DIR_TMP=$(mktemp -d ${CUR_DIR}/mkeuler.XXXXXX)
	echo "${DIR_TMP}" > ${CUR_DIR}/.stage
else
	DIR_TMP=`cat ${CUR_DIR}/.stage`
	echo "Unfinised ISO build exist"
fi

DIR_CDROM=${DIR_TMP}/cdrom
DIR_OPENEULER_FILE=${DIR_TMP}/openEuler_file
DIR_INSTALL_IMG=${DIR_TMP}/install_img
DIR_ROOTFS_IMG=${DIR_TMP}/rootfs_img

function stage() {
	if [[ $1 != "finished" ]]; then
		echo "${DIR_TMP}" > ${CUR_DIR}/.stage
	else
		rm ${CUR_DIR}/.stage
	fi
}

function clean() {
    losetup -d /dev/loop0 /dev/loop1 || true
    umount /dev/loop0 /dev/loop1 || true
    if [[ -e ${CUR_DIR}/.stage ]]; then
	    rm -rf ${DIR_TMP}
	    stage "finished"
    fi
}

function prepare() {
    echo "Preparing workdir with ${ISO_SOURCE} ..."
    
    mkdir -p ${DIR_CDROM} ${DIR_OPENEULER_FILE} ${DIR_INSTALL_IMG} ${DIR_ROOTFS_IMG}
    mount -t iso9660 -o ro ${ISO_SOURCE} ${DIR_CDROM}
    cp -r ${DIR_CDROM}/* ${DIR_OPENEULER_FILE}/
    if [[ ! -e ${DIR_OPENEULER_FILE}/.discinfo ]]; then
        # https://gitee.com/src-openeuler/anaconda/issues/I2E172
        cp ${DIR_CDROM}/.discinfo ${DIR_OPENEULER_FILE}/
    fi
    if [[ ! -e ${DIR_OPENEULER_FILE}/.treeinfo ]]; then
        cp ${DIR_CDROM}/.treeinfo ${DIR_OPENEULER_FILE}/
    fi
    if [[ ! -e ${DIR_INSTALL_IMG}/install.img ]]; then
        cp -r ${DIR_OPENEULER_FILE}/images/install.img ${DIR_INSTALL_IMG}
    fi

    pushd ${DIR_INSTALL_IMG}
    if [[ ! -d squashfs-root/LiveOS ]]; then
        unsquashfs install.img
    fi
    cd squashfs-root/LiveOS
    losetup /dev/loop1 rootfs.img
    kpartx -av rootfs.img
    mount /dev/loop1 ${DIR_ROOTFS_IMG}
    popd
    echo "Done..."
}

function replace() {
    echo "Replacing installer rootfs with ${ARCH_ROOTFS_DIR} and ${COMMON_ROOTFS_DIR} ..."
    cp -r ${ARCH_ROOTFS_DIR}/* ${DIR_ROOTFS_IMG} ||
    cp ${ARCH_ROOTFS_DIR}/.buildstamp ${DIR_ROOTFS_IMG}
    cp -r ${COMMON_ROOTFS_DIR}/* ${DIR_ROOTFS_IMG}

    echo "Replacing installer bootloader with ${ARCH_BOOTLOADER_DIR} ..."
    cp -r ${ARCH_BOOTLOADER_DIR}/* ${DIR_OPENEULER_FILE}
    chmod 444 ${DIR_OPENEULER_FILE}/EFI/BOOT/grub.cfg

    echo "Done..."
}

function generate() {
    echo "Generating install.img ..."
    mksquashfs ${DIR_INSTALL_IMG}/squashfs-root ./install.img
    rm -f ${DIR_OPENEULER_FILE}/images/install.img
    mv ./install.img ${DIR_OPENEULER_FILE}/images/
    umount ${DIR_ROOTFS_IMG}
    losetup -d /dev/loop0 /dev/loop1 || true
    umount /dev/loop0 /dev/loop1 || true

    local FINAL_ISO_OUTPUT=$(dirname $(readlink -f ${ISO_OUTPUT}))/$(basename ${ISO_OUTPUT})
    echo "Generating ISO ${FINAL_ISO_OUTPUT} by ISO_VOLID ${ISO_VOLID} ..."
    pushd ${DIR_OPENEULER_FILE}
    if [[ $ISO_ARCH == "x86_64" ]]; then
        echo "Building the x86_64 ISO"
        mkisofs -R -J -T -r -l -d -joliet-long -allow-multidot -allow-leading-dots -no-bak \
            -V ${ISO_VOLID} -o ${FINAL_ISO_OUTPUT} \
            -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot \
            -boot-load-size 4 -boot-info-table \
            -eltorito-alt-boot -eltorito-boot images/efiboot.img -no-emul-boot ./
    else
        echo "Building the aarch64 ISO"
        mkisofs -R -J -T -r -l -d -joliet-long -allow-multidot -allow-leading-dots -no-bak \
            -V ${ISO_VOLID} -o ${FINAL_ISO_OUTPUT} \
            -eltorito-boot images/efiboot.img -no-emul-boot ./
    fi
    popd

    pushd ${CUR_DIR}
    [ -x "$(command -v implantisomd5)" ] && echo "Trying implantisomd5 ISO ..." && implantisomd5 $(basename ${ISO_OUTPUT})
    [ -x "$(command -v sha256sum)" ] && echo "Trying to create sha256sum file ..." && sha256sum $(basename ${ISO_OUTPUT}) > $(basename ${ISO_OUTPUT}).sha256sum
    popd

    clean 
    echo "Please check the output ISO: ${FINAL_ISO_OUTPUT}"
    echo "Done..."
}

function default() {
    prepare
    replace
    generate
}

function usage() {
	cat <<EOF
${0##*/} can create a custom openEuler installation ISOs by modifying an existing ISO
these options are recognized:
    prepare                (action)to prepare the workdir with ISO_SOURCE
    replace                (action)to replace the custom files with ROOTFS_DIR and BOOTLOADER_DIR
    generate               (action)to generate an ISO to ISO_OUTPUT
    default                (action)to run prepare, replace and generate actions
    clean                  (action)to clean the workdir
    -i ISO_SOURCE          use this source ISO instead of default value
    -o ISO_OUTPUT          use this output ISO instead of default value
    -volid ISO_VOLID       use this ISO volid instead of default value
    -arch ISO_ARCH         x86_64(default) or aarch64
EOF
}

until [ "$#" = "0" ] ; do
    case "$1" in
        default | prepare | replace | generate | clean)
            ACTION=$1
            shift
            ;;
        -i)
            ISO_SOURCE=$2
            shift 2
            ;;
        -o)
            ISO_OUTPUT=$2
            shift 2
            ;;
        -volid)
            ISO_VOLID=$2
            shift 2
            ;;
        -arch)
            ISO_ARCH=$2
            shift 2
            ;;
        -h|--help|-v|--version)
	    usage	
            exit 1
            ;;
        *)
            echo "unknown option '$1'" >&2
	    usage
            exit 1
             ;;
    esac
done

ISO_ARCH=${ISO_ARCH:-"x86_64"}
ISO_SOURCE=${ISO_SOURCE:-"./openEuler/openEuler-20.03-LTS-SP2-${ISO_ARCH}-dvd.iso"}
ISO_OUTPUT=${ISO_OUTPUT:-"${CUR_DIR}/suseEuler-1.2-LTS-${ISO_ARCH}-dvd.iso"}
ISO_VOLID=${ISO_VOLID:-"suseEuler-1.2-LTS-${ISO_ARCH}"}

ARCH_ROOTFS_DIR=${CUR_DIR}/${ISO_ARCH}/rootfs
ARCH_BOOTLOADER_DIR=${CUR_DIR}/${ISO_ARCH}/bootloader
COMMON_ROOTFS_DIR=${CUR_DIR}/common/rootfs

if [[ -z "${ACTION}" ]]; then
	echo "Please specify an action for processing"
	usage
	exit 1
fi

$ACTION
