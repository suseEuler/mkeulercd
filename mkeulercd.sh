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

function clean() {
    losetup -d /dev/loop0 /dev/loop1 || true
    umount /dev/loop0 /dev/loop1 || true
    rm -rf /mnt/cdrom /mnt/openEuler_file /mnt/install_img /mnt/rootfs_img
}

function prepare() {
    echo "Preparing workdir with ${ISO_SOURCE} ..."
    mkdir -p /mnt/cdrom /mnt/openEuler_file /mnt/install_img /mnt/rootfs_img
    mount -t iso9660 -o ro ${ISO_SOURCE} /mnt/cdrom/
    if [[ ! -e /mnt/openEuler_file/.discinfo ]]; then
        cp -r /mnt/cdrom/* /mnt/openEuler_file/
        # https://gitee.com/src-openeuler/anaconda/issues/I2E172
        cp /mnt/cdrom/.discinfo /mnt/openEuler_file/
    fi
    if [[ ! -e /mnt/openEuler_file/.treeinfo ]]; then
        cp -r /mnt/cdrom/* /mnt/openEuler_file/
        cp /mnt/cdrom/.treeinfo /mnt/openEuler_file/
    fi
    if [[ ! -e /mnt/install_img/install.img ]]; then
        cp -r /mnt/openEuler_file/images/install.img /mnt/install_img
    fi

    pushd /mnt/install_img
    if [[ ! -d squashfs-root/LiveOS ]]; then
        unsquashfs install.img
    fi
    cd squashfs-root/LiveOS
    losetup /dev/loop1 rootfs.img
    kpartx -av rootfs.img
    mount /dev/loop1 /mnt/rootfs_img
    popd
    echo "Done..."
}

function replace() {
    echo "Replacing installer rootfs with ${ARCH_ROOTFS_DIR} and ${COMMON_ROOTFS_DIR} ..."
    #cp -r ${ARCH_ROOTFS_DIR}/* /mnt/rootfs_img
    cp ${ARCH_ROOTFS_DIR}/.buildstamp /mnt/rootfs_img
    cp -r ${COMMON_ROOTFS_DIR}/* /mnt/rootfs_img

    echo "Replacing installer bootloader with ${ARCH_BOOTLOADER_DIR} ..."
    cp -r ${ARCH_BOOTLOADER_DIR}/* /mnt/openEuler_file
    chmod 444 /mnt/openEuler_file/EFI/BOOT/grub.cfg

    echo "Done..."
}

function generate() {
    echo "Generating install.img ..."
    mksquashfs /mnt/install_img/squashfs-root ./install.img
    rm -f /mnt/openEuler_file/images/install.img
    mv ./install.img /mnt/openEuler_file/images/
    umount /mnt/rootfs_img
    losetup -d /dev/loop0 /dev/loop1 || true
    umount /dev/loop0 /dev/loop1 || true

    local FINAL_ISO_OUTPUT=$(dirname $(readlink -f ${ISO_OUTPUT}))/$(basename ${ISO_OUTPUT})
    echo "Generating ISO ${FINAL_ISO_OUTPUT} by ISO_VOLID ${ISO_VOLID} ..."
    pushd /mnt/openEuler_file
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

    echo "Please check the output ISO: ${FINAL_ISO_OUTPUT}"
    echo "Done..."
}

function default() {
    prepare
    replace
    generate
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
            cat <<EOF
${0##*/} can create a custom openEuler installation ISOs by modifying an existing ISO
these options are recognized:
    prepare                to prepare the workdir with ISO_SOURCE
    replace                to replace the custom files with ROOTFS_DIR and BOOTLOADER_DIR
    generate               to generate an ISO to ISO_OUTPUT
    default                to run prepare, replace and generate actions
    clean                  to clean the workdir
    -i ISO_SOURCE          use this source ISO instead of default value
    -o ISO_OUTPUT          use this output ISO instead of default value
    -volid ISO_VOLID       use this ISO volid instead of default value
    -arch ISO_ARCH         x86_64(default) or aarch64
EOF
            exit 1
            ;;
        *)
            echo "unknown option '$1'" >&2
            exit 1
             ;;
    esac
done

ISO_ARCH=${ISO_ARCH:-"x86_64"}
ISO_SOURCE=${ISO_SOURCE:-"/opt/openEuler/openEuler-20.03-LTS-SP2-${ISO_ARCH}-dvd.iso"}
ISO_OUTPUT=${ISO_OUTPUT:-"${CUR_DIR}/suseEuler-1.2-LTS-${ISO_ARCH}-dvd.iso"}
ISO_VOLID=${ISO_VOLID:-"suseEuler-1.2-LTS-${ISO_ARCH}"}

ARCH_ROOTFS_DIR=${CUR_DIR}/${ISO_ARCH}/rootfs
ARCH_BOOTLOADER_DIR=${CUR_DIR}/${ISO_ARCH}/bootloader
COMMON_ROOTFS_DIR=${CUR_DIR}/common/rootfs

$ACTION
