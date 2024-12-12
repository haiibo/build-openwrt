#!/bin/bash

# Set default theme to luci-theme-argon
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

# Disable IPV6 ula prefix
# sed -i 's/^[^#].*option ula/#&/' /etc/config/network

# Check file system during boot
# uci set fstab.@global[0].check_fs=1
# uci commit fstab

# Set etc/openwrt_release
sed -i "s/DISTRIB_REVISION=.*/DISTRIB_REVISION=''/g" /etc/openwrt_release
repo=$(cat /etc/openwrt_release | grep DISTRIB_DESCRIPTION= | awk -F "'" '{print $2}' | awk '{print $1}')
sed -i "s/DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION='$repo R$(date +%y.%m.%d)'/g" /etc/openwrt_release

exit 0
