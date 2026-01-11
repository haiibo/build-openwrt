#!/bin/bash

# 打包toolchain目录
if [[ $REBUILD_TOOLCHAIN = 'true' ]]; then
    cd $OPENWRT_PATH
    sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
    [ -d ".ccache" ] && (ccache=".ccache"; ls -alh .ccache)
    du -h --max-depth=1 ./staging_dir
    tar -I zstdmt -cf $GITHUB_WORKSPACE/output/$CACHE_NAME.tzst staging_dir/host* staging_dir/tool* $ccache
    ls -lh $GITHUB_WORKSPACE/output
    [ -e $GITHUB_WORKSPACE/output/$CACHE_NAME.tzst ] || exit 1
    exit 0
fi

[ -d $GITHUB_WORKSPACE/output ] || mkdir $GITHUB_WORKSPACE/output

color() {
    case $1 in
        cr) echo -e "\e[1;31m$2\e[0m" ;;  # 红色
        cg) echo -e "\e[1;32m$2\e[0m" ;;  # 绿色
        cy) echo -e "\e[1;33m$2\e[0m" ;;  # 黄色
        cb) echo -e "\e[1;34m$2\e[0m" ;;  # 蓝色
        cp) echo -e "\e[1;35m$2\e[0m" ;;  # 紫色
        cc) echo -e "\e[1;36m$2\e[0m" ;;  # 青色
    esac
}

status() {
    local check=$? end_time=$(date '+%H:%M:%S') total_time
    total_time="==> 用时 $[$(date +%s -d $end_time) - $(date +%s -d $begin_time)] 秒"
    [[ $total_time =~ [0-9]+ ]] || total_time=""
    if [[ $check = 0 ]]; then
        printf "%-62s %s %s %s %s %s %s %s\n" \
        $(color cy $1) [ $(color cg ✔) ] $(echo -e "\e[1m$total_time")
    else
        printf "%-62s %s %s %s %s %s %s %s\n" \
        $(color cy $1) [ $(color cr ✕) ] $(echo -e "\e[1m$total_time")
    fi
}

find_dir() {
    find $1 -maxdepth 3 -type d -name $2 -print -quit 2>/dev/null
}

print_info() {
    printf "%s %-40s %s %s %s\n" $1 $2 $3 $4 $5
}

# 添加整个源仓库(git clone)
git_clone() {
    local repo_url branch target_dir current_dir
    if [[ "$1" == */* ]]; then
        repo_url="$1"
        shift
    else
        branch="-b $1 --single-branch"
        repo_url="$2"
        shift 2
    fi
    if [[ -n "$@" ]]; then
        target_dir="$@"
    else
        target_dir="${repo_url##*/}"
    fi
    git clone -q $branch --depth=1 $repo_url $target_dir 2>/dev/null || {
        print_info $(color cr 拉取) $repo_url [ $(color cr ✕) ]
        return 0
    }
    rm -rf $target_dir/{.git*,README*.md,LICENSE}
    current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
    if ([[ -d $current_dir ]] && rm -rf $current_dir); then
        mv -f $target_dir ${current_dir%/*}
        print_info $(color cg 替换) $target_dir [ $(color cg ✔) ]
    else
        mv -f $target_dir $destination_dir
        print_info $(color cb 添加) $target_dir [ $(color cb ✔) ]
    fi
}

# 添加源仓库内的指定目录
clone_dir() {
    local repo_url branch temp_dir=$(mktemp -d)
    if [[ "$1" == */* ]]; then
        repo_url="$1"
        shift
    else
        branch="-b $1 --single-branch"
        repo_url="$2"
        shift 2
    fi
    git clone -q $branch --depth=1 $repo_url $temp_dir 2>/dev/null || {
        print_info $(color cr 拉取) $repo_url [ $(color cr ✕) ]
        return 0
    }
    local target_dir source_dir current_dir
    for target_dir in "$@"; do
        source_dir=$(find_dir "$temp_dir" "$target_dir")
        [[ -d $source_dir ]] || \
        source_dir=$(find $temp_dir -maxdepth 4 -type d -name $target_dir -print -quit) && \
        [[ -d $source_dir ]] || {
            print_info $(color cr 查找) $target_dir [ $(color cr ✕) ]
            continue
        }
        current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
        if ([[ -d $current_dir ]] && rm -rf $current_dir); then
            mv -f $source_dir ${current_dir%/*}
            print_info $(color cg 替换) $target_dir [ $(color cg ✔) ]
        else
            mv -f $source_dir $destination_dir
            print_info $(color cb 添加) $target_dir [ $(color cb ✔) ]
        fi
    done
    rm -rf $temp_dir
}

# 添加源仓库内的所有目录
clone_all() {
    local repo_url branch temp_dir=$(mktemp -d)
    if [[ "$1" == */* ]]; then
        repo_url="$1"
        shift
    else
        branch="-b $1 --single-branch"
        repo_url="$2"
        shift 2
    fi
    git clone -q $branch --depth=1 $repo_url $temp_dir 2>/dev/null || {
        print_info $(color cr 拉取) $repo_url [ $(color cr ✕) ]
        return 0
    }
    local target_dir source_dir current_dir
    for target_dir in $(ls -l $temp_dir/$@ | awk '/^d/ {print $NF}'); do
        source_dir=$(find_dir "$temp_dir" "$target_dir")
        current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
        if ([[ -d $current_dir ]] && rm -rf $current_dir); then
            mv -f $source_dir ${current_dir%/*}
            print_info $(color cg 替换) $target_dir [ $(color cg ✔) ]
        else
            mv -f $source_dir $destination_dir
            print_info $(color cb 添加) $target_dir [ $(color cb ✔) ]
        fi
    done
    rm -rf $temp_dir
}

# 设置编译源码与分支
REPO_URL="https://github.com/immortalwrt/immortalwrt"
echo "REPO_URL=$REPO_URL" >>$GITHUB_ENV
REPO_BRANCH="openwrt-24.10"
echo "REPO_BRANCH=$REPO_BRANCH" >>$GITHUB_ENV

# 拉取编译源码
begin_time=$(date '+%H:%M:%S')
cd /workdir
git clone -q -b $REPO_BRANCH --single-branch $REPO_URL openwrt
status "拉取编译源码"
ln -sf /workdir/openwrt $GITHUB_WORKSPACE/openwrt
[ -d openwrt ] && cd openwrt || exit
echo "OPENWRT_PATH=$PWD" >>$GITHUB_ENV

# 设置全局变量
begin_time=$(date '+%H:%M:%S')

# 源仓库与分支
SOURCE_REPO=$(basename $REPO_URL)
echo "SOURCE_REPO=$SOURCE_REPO" >>$GITHUB_ENV
echo "LITE_BRANCH=${REPO_BRANCH#*-}" >>$GITHUB_ENV

# 平台架构
TARGET_NAME=$(grep -oP "^CONFIG_TARGET_\K[a-z0-9]+(?==y)" $GITHUB_WORKSPACE/$CONFIG_FILE)
SUBTARGET_NAME=$(grep -oP "^CONFIG_TARGET_${TARGET_NAME}_\K[a-z0-9]+(?==y)" $GITHUB_WORKSPACE/$CONFIG_FILE)
DEVICE_TARGET=$TARGET_NAME-$SUBTARGET_NAME
echo "DEVICE_TARGET=$DEVICE_TARGET" >>$GITHUB_ENV

# 内核版本
KERNEL=$(grep -oP 'KERNEL_PATCHVER:=\K[\d\.]+' target/linux/$TARGET_NAME/Makefile)
KERNEL_FILE="include/kernel-$KERNEL"
[ -e "$KERNEL_FILE" ] || KERNEL_FILE="target/linux/generic/kernel-$KERNEL"
KERNEL_VERSION=$(grep -oP 'LINUX_KERNEL_HASH-\K[\d\.]+' $KERNEL_FILE)
echo "KERNEL_VERSION=$KERNEL_VERSION" >>$GITHUB_ENV

# toolchain缓存文件名
TOOLS_HASH=$(git log --pretty=tformat:"%h" -n1 tools toolchain)
CACHE_NAME="$SOURCE_REPO-${REPO_BRANCH#*-}-$DEVICE_TARGET-cache-$TOOLS_HASH"
echo "CACHE_NAME=$CACHE_NAME" >>$GITHUB_ENV

# 源码更新信息
echo "COMMIT_AUTHOR=$(git show -s --date=short --format="作者: %an")" >>$GITHUB_ENV
echo "COMMIT_DATE=$(git show -s --date=short --format="时间: %ci")" >>$GITHUB_ENV
echo "COMMIT_MESSAGE=$(git show -s --date=short --format="内容: %s")" >>$GITHUB_ENV
echo "COMMIT_HASH=$(git show -s --date=short --format="hash: %H")" >>$GITHUB_ENV
status "生成全局变量"

# 下载部署toolchain缓存
if [[ $TOOLCHAIN = 'true' ]]; then
    cache_xa=$(curl -sL https://api.github.com/repos/$GITHUB_REPOSITORY/releases | awk -F '"' '/download_url/{print $4}' | grep $CACHE_NAME)
    cache_xc=$(curl -sL https://api.github.com/repos/haiibo/toolchain-cache/releases | awk -F '"' '/download_url/{print $4}' | grep $CACHE_NAME)
    if [[ $cache_xa || $cache_xc ]]; then
        begin_time=$(date '+%H:%M:%S')
        wget -qc -t=3 "${cache_xa:-$cache_xc}"
        if [ -e *.tzst ]; then
            tar -I unzstd -xf *.tzst || tar -xf *.tzst
            [ $cache_xa ] || (cp *.tzst $GITHUB_WORKSPACE/output && echo "OUTPUT_RELEASE=true" >>$GITHUB_ENV)
            [ -d staging_dir ] && sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
            status "下载部署toolchain缓存"
        fi
    else
        echo "REBUILD_TOOLCHAIN=true" >>$GITHUB_ENV
    fi
else
    echo "REBUILD_TOOLCHAIN=true" >>$GITHUB_ENV
fi

# 更新&安装插件
begin_time=$(date '+%H:%M:%S')
./scripts/feeds update -a 1>/dev/null 2>&1
./scripts/feeds install -a 1>/dev/null 2>&1
status "更新&安装插件"

# 创建插件保存目录
destination_dir="package/A"
[ -d $destination_dir ] || mkdir -p $destination_dir

# 添加额外插件
clone_dir openwrt-23.05 https://github.com/coolsnowwolf/luci luci-app-adguardhome
clone_all https://github.com/lwb1978/openwrt-gecoosac
clone_dir https://github.com/sirpdboy/luci-app-ddns-go ddns-go luci-app-ddns-go

clone_all https://github.com/sbwml/luci-app-alist
clone_all https://github.com/sbwml/luci-app-mosdns
git_clone https://github.com/sbwml/packages_lang_golang golang

clone_all https://github.com/linkease/istore-ui
clone_all https://github.com/linkease/istore luci

clone_all https://github.com/brvphoenix/luci-app-wrtbwmon
clone_all https://github.com/brvphoenix/wrtbwmon

# 科学上网插件
clone_all https://github.com/fw876/helloworld
clone_all https://github.com/Openwrt-Passwall/openwrt-passwall-packages
clone_all https://github.com/Openwrt-Passwall/openwrt-passwall
clone_all https://github.com/Openwrt-Passwall/openwrt-passwall2
clone_dir https://github.com/vernesong/OpenClash luci-app-openclash
clone_all https://github.com/nikkinikki-org/OpenWrt-nikki
clone_all https://github.com/nikkinikki-org/OpenWrt-momo
clone_dir https://github.com/QiuSimons/luci-app-daed daed luci-app-daed
git_clone https://github.com/immortalwrt/homeproxy luci-app-homeproxy

# Themes
git_clone https://github.com/kiddin9/luci-theme-edge
git_clone https://github.com/jerrykuku/luci-theme-argon
git_clone https://github.com/jerrykuku/luci-app-argon-config
git_clone https://github.com/eamonxg/luci-theme-aurora
git_clone https://github.com/eamonxg/luci-app-aurora-config
git_clone https://github.com/sirpdboy/luci-theme-kucat
git_clone https://github.com/sirpdboy/luci-app-kucat-config

# 晶晨宝盒
clone_all https://github.com/ophub/luci-app-amlogic
sed -i "s|firmware_repo.*|firmware_repo 'https://github.com/$GITHUB_REPOSITORY'|g" $destination_dir/luci-app-amlogic/root/etc/config/amlogic
# sed -i "s|kernel_path.*|kernel_path 'https://github.com/ophub/kernel'|g" $destination_dir/luci-app-amlogic/root/etc/config/amlogic
sed -i "s|ARMv8|$RELEASE_TAG|g" $destination_dir/luci-app-amlogic/root/etc/config/amlogic

# 加载个人设置
begin_time=$(date '+%H:%M:%S')

[ -e $GITHUB_WORKSPACE/files ] && mv $GITHUB_WORKSPACE/files files

# 设置固件rootfs大小
if [ $PART_SIZE ]; then
    sed -i '/ROOTFS_PARTSIZE/d' $GITHUB_WORKSPACE/$CONFIG_FILE
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=$PART_SIZE" >>$GITHUB_WORKSPACE/$CONFIG_FILE
fi

# 修改默认ip地址
[ $IP_ADDRESS ] && sed -i '/n) ipad/s/".*"/"'"$IP_ADDRESS"'"/' package/base-files/files/bin/config_generate

# 更改默认shell为zsh
# sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd

# ttyd免登录
sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

# 设置root用户密码为password
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.::0:99999:7:::/g' package/base-files/files/etc/shadow

# 更改argon主题背景
cp -f $GITHUB_WORKSPACE/images/bg1.jpg feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg

# 删除主题默认设置
# find $destination_dir/luci-theme-*/ -type f -name '*luci-theme-*' -exec sed -i '/set luci.main.mediaurlbase/d' {} +

# 设置nlbwmon独立菜单
sed -i 's/services\/nlbw/nlbw/g; /path/s/admin\///g' feeds/luci/applications/luci-app-nlbwmon/root/usr/share/luci/menu.d/luci-app-nlbwmon.json
sed -i 's/services\///g' feeds/luci/applications/luci-app-nlbwmon/htdocs/luci-static/resources/view/nlbw/config.js

# 修复Makefile路径
find $destination_dir -type f -name "Makefile" | xargs sed -i \
    -e 's?\.\./\.\./\(lang\|devel\)?$(TOPDIR)/feeds/packages/\1?' \
    -e 's?\.\./\.\./luci.mk?$(TOPDIR)/feeds/luci/luci.mk?'

# 修改qca-nss-drv启动顺序
drv_path="feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$drv_path" ]; then
    sed -i 's/START=.*/START=85/g' $drv_path
fi

# 修改qca-nss-pbuf启动顺序
pbuf_path="package/kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$pbuf_path" ]; then
    sed -i 's/START=.*/START=86/g' $pbuf_path
fi

# 移除attendedsysupgrade
find "feeds/luci/collections" -name "Makefile" | while read -r makefile; do
    if grep -q "luci-app-attendedsysupgrade" "$makefile"; then
        sed -i "/luci-app-attendedsysupgrade/d" "$makefile"
    fi
done

# 转换插件语言翻译
for e in $(ls -d $destination_dir/luci-*/po feeds/luci/applications/luci-*/po); do
    if [[ -d $e/zh-cn && ! -d $e/zh_Hans ]]; then
        ln -s zh-cn $e/zh_Hans 2>/dev/null
    elif [[ -d $e/zh_Hans && ! -d $e/zh-cn ]]; then
        ln -s zh_Hans $e/zh-cn 2>/dev/null
    fi
done
status "加载个人设置"

# 更新配置文件
begin_time=$(date '+%H:%M:%S')
[ -e $GITHUB_WORKSPACE/$CONFIG_FILE ] && cp -f $GITHUB_WORKSPACE/$CONFIG_FILE .config
make defconfig 1>/dev/null 2>&1
status "更新配置文件"

# 下载openclash运行内核
if [[ "$CLASH_KERNEL" =~ ^(amd64|arm64|armv7|armv6|armv5|386)$ ]] && grep -q "luci-app-openclash=y" .config; then
    begin_time=$(date '+%H:%M:%S')
    chmod +x $GITHUB_WORKSPACE/scripts/preset-clash-core.sh
    $GITHUB_WORKSPACE/scripts/preset-clash-core.sh $CLASH_KERNEL
    status "下载openclash运行内核"
fi

# 下载zsh终端工具
if grep -q "zsh=y" .config; then
    begin_time=$(date '+%H:%M:%S')
    chmod +x $GITHUB_WORKSPACE/scripts/preset-terminal-tools.sh
    $GITHUB_WORKSPACE/scripts/preset-terminal-tools.sh
    status "下载zsh终端工具"
fi

echo -e "$(color cy 当前编译机型) $(color cb $SOURCE_REPO-${REPO_BRANCH#*-}-$DEVICE_TARGET-$KERNEL_VERSION)"

# 更改固件文件名
# sed -i "s/\$(VERSION_DIST_SANITIZED)/$SOURCE_REPO-${REPO_BRANCH#*-}-$KERNEL_VERSION/" include/image.mk
# sed -i "/IMG_PREFIX:/ {s/=/=$SOURCE_REPO-${REPO_BRANCH#*-}-$KERNEL_VERSION-\$(shell date +%y.%m.%d)-/}" include/image.mk

color cp "脚本运行完成！"
