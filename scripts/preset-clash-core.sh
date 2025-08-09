#!/bin/bash

[ -d files/etc/openclash/core ] || mkdir -p files/etc/openclash/core

CLASH_META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-${1}.tar.gz"
COUNTRY_URL="https://raw.githubusercontent.com/alecthw/mmdb_china_ip_list/release/lite/Country.mmdb"
GEOIP_URL="https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geoip.dat"
GEOSITE_URL="https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geosite.dat"

wget -qO- $CLASH_META_URL | tar xOz > files/etc/openclash/core/clash_meta
wget -qO- $COUNTRY_URL > files/etc/openclash/Country.mmdb
wget -qO- $GEOIP_URL > files/etc/openclash/GeoIP.dat
wget -qO- $GEOSITE_URL > files/etc/openclash/GeoSite.dat

chmod +x files/etc/openclash/core/clash*
