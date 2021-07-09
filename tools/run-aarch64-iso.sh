#!/bin/bash
# Install distro from an ISO onto a virtual disk image
# . runqemu-iso <distro>.iso
#
# QEMU_EFI.img:
#   wget https://releases.linaro.org/components/kernel/uefi-linaro/latest/release/qemu64/QEMU_EFI.img.gz
#   gunzip QEMU_EFI.img.gz

iso=$1
os=${iso%.iso}
size=8G

disk_img=$os.qcow2
efi_img=$os.efi

qemu-img create -f qcow2 $disk_img ${size}
qemu-img create -f qcow2 $efi_img 64M

exec qemu-system-aarch64 \
    -cpu cortex-a53 -M virt -m 4096 -nographic -smp 2 -boot d \
    -drive if=pflash,format=raw,file=QEMU_EFI.img \
    -drive if=pflash,format=qcow2,file=${efi_img} \
    -device virtio-scsi-device \
    -device scsi-cd,drive=cdrom \
    -device virtio-blk-device,drive=hd0 \
    -drive file=${iso},id=cdrom,media=cdrom,if=none \
    -drive file=${disk_img},id=hd0,if=none
