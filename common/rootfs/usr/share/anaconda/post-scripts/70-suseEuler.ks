%post --nochroot

echo "Update for suseEuler branding"

pushd $ANA_INSTALL_PATH
# update GRUB menu
if [ -e ./boot/efi/EFI/openEuler/grub.cfg ]; then
    echo "Update ./boot/efi/EFI/openEuler/grub.cfg ..."
    sed -i 's/openEuler/suseEuler/g' ./boot/efi/EFI/openEuler/grub.cfg
    sed -i 's/20.03 (LTS-SP2)/1.2 (LTS)/g' ./boot/efi/EFI/openEuler/grub.cfg
fi
if [ -e ./boot/grub2/grub.cfg ]; then
    echo "Update ./boot/grub2/grub.cfg ..."
    sed -i 's/openEuler/suseEuler/g' ./boot/grub2/grub.cfg
    sed -i 's/20.03 (LTS-SP2)/1.2 (LTS)/g' ./boot/grub2/grub.cfg
fi
popd

# update /etc/os-release
# cp /etc/os-release $ANA_INSTALL_PATH/etc/os-release

# update /etc/openEuler-release

# update EULA
rm -f $ANA_INSTALL_PATH/usr/share/openEuler-release/EULA
mkdir -p $ANA_INSTALL_PATH/usr/share/suseEuler-release
cp /usr/share/suseEuler-release/EULA $ANA_INSTALL_PATH/usr/share/suseEuler-release/

%end
