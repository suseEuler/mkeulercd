#!/bin/bash
# Install distro from an ISO onto a virtual disk image
# . runqemu-iso <distro>.iso
#
# openSUSE 15.3
# please disable the firewalld with yast
#   zypper in qemu qemu-arch
#


iso=$1
os=${iso%.iso}
size=5G

disk_img=$os.qcow2
efi_img=$os.efi

qemu-img create -f qcow2 $disk_img ${size}
qemu-img create -f qcow2 $efi_img 64M
# -nographic
# -vnc :1 -monitor stdio
# -bios /usr/share/qemu/qemu-uefi-aarch64.bin
exec qemu-system-aarch64 \
    -cpu cortex-a57 -M virt -m 4096 -smp 2 -boot d \
    -bios /usr/share/qemu/qemu-uefi-aarch64.bin \
    -device virtio-scsi-device \
    -device scsi-cd,drive=cdrom \
    -device virtio-blk-device,drive=hd0 \
    -device virtio-rng-pci \
    -drive file=${iso},id=cdrom,media=cdrom,if=none \
    -drive file=${disk_img},id=hd0,if=none \
    -rtc base=utc,clock=host \
    -monitor stdio \
    -vnc 0.0.0.0:1
