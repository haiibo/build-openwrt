#!/bin/bash

color() {
    case $1 in
        cy) echo -e "\033[1;33m$2\033[0m" ;;
        cr) echo -e "\033[1;31m$2\033[0m" ;;
        cg) echo -e "\033[1;32m$2\033[0m" ;;
        cb) echo -e "\033[1;34m$2\033[0m" ;;
    esac
}

status() {
    CHECK=$?
    END_TIME=$(date '+%H:%M:%S')
    _date=" ==> 用时 $[$(date +%s -d "$END_TIME") - $(date +%s -d "$BEGIN_TIME")] 秒"
    [[ $_date =~ [0-9]+ ]] || _date=""
    if [[ $CHECK = 0 ]]; then
        printf "%-62s %s %s %s %s %s %s %s\n" \
        $(echo -e "$(color cy $1) [ $(color cg ✔) ]${_date}")
    else
        printf "%-62s %s %s %s %s %s %s %s\n" \
        $(echo -e "$(color cy $1) [ $(color cr ✕) ]${_date}")
    fi
}

_find() {
    find $1 -maxdepth 3 -type d -name $2 -print -quit 2>/dev/null
}

_printf() {
    awk '{printf "%s %-40s %s %s %s\n" ,$1,$2,$3,$4,$5}'
}

# 添加整个源仓库(git clone)
git_clone() {
    local repo_url branch
    if [[ "$1" == */* ]]; then
        repo_url="$1"
        shift
    else
        branch="-b $1 --single-branch"
        repo_url="$2"
        shift 2
    fi
    local target_dir current_dir
    if [[ -n "$@" ]]; then
        target_dir="$@"
    else
        target_dir="${repo_url##*/}"
    fi
    git clone -q $branch --depth=1 $repo_url $target_dir 2>/dev/null || {
        echo -e "$(color cr 拉取) $repo_url [ $(color cr ✕) ]" | _printf
        return 0
    }
    rm -rf $target_dir/{.git*,README*.md,LICENSE}
    current_dir=$(_find "package/ feeds/ target/" "$target_dir")
    if ([[ -d "$current_dir" ]] && rm -rf $current_dir); then
        mv -f $target_dir ${current_dir%/*}
        echo -e "$(color cg 替换) $target_dir [ $(color cg ✔) ]" | _printf
    else
        mv -f $target_dir $destination_dir
        echo -e "$(color cb 添加) $target_dir [ $(color cb ✔) ]" | _printf
    fi
}

# 添加源仓库内的指定目录
clone_dir() {
    local repo_url branch
    if [[ "$1" == */* ]]; then
        repo_url="$1"
        shift
    else
        branch="-b $1 --single-branch"
        repo_url="$2"
        shift 2
    fi
    local temp_dir=$(mktemp -d)
    git clone -q $branch --depth=1 $repo_url $temp_dir 2>/dev/null || {
        echo -e "$(color cr 拉取) $repo_url [ $(color cr ✕) ]" | _printf
        return 0
    }
    for target_dir in "$@"; do
        local source_dir current_dir
        source_dir=$(_find "$temp_dir" "$target_dir")
        [[ -d "$source_dir" ]] || \
        source_dir=$(find "$temp_dir" -maxdepth 4 -type d -name "$target_dir" -print -quit) && \
        [[ -d "$source_dir" ]] || {
            echo -e "$(color cr 查找) $target_dir [ $(color cr ✕) ]" | _printf
            continue
        }
        current_dir=$(_find "package/ feeds/ target/" "$target_dir")
        if ([[ -d "$current_dir" ]] && rm -rf $current_dir); then
            mv -f $source_dir ${current_dir%/*}
            echo -e "$(color cg 替换) $target_dir [ $(color cg ✔) ]" | _printf
        else
            mv -f $source_dir $destination_dir
            echo -e "$(color cb 添加) $target_dir [ $(color cb ✔) ]" | _printf
        fi
    done
    rm -rf $temp_dir
}

# 添加源仓库内的所有目录
clone_all() {
    local repo_url branch
    if [[ "$1" == */* ]]; then
        repo_url="$1"
        shift
    else
        branch="-b $1 --single-branch"
        repo_url="$2"
        shift 2
    fi
    local temp_dir=$(mktemp -d)
    git clone -q $branch --depth=1 $repo_url $temp_dir 2>/dev/null || {
        echo -e "$(color cr 拉取) $repo_url [ $(color cr ✕) ]" | _printf
        return 0
    }
    for target_dir in $(ls -l $temp_dir/$@ | awk '/^d/{print $NF}'); do
        local source_dir current_dir
        source_dir=$(_find "$temp_dir" "$target_dir")
        current_dir=$(_find "package/ feeds/ target/" "$target_dir")
        if ([[ -d "$current_dir" ]] && rm -rf $current_dir); then
            mv -f $source_dir ${current_dir%/*}
            echo -e "$(color cg 替换) $target_dir [ $(color cg ✔) ]" | _printf
        else
            mv -f $source_dir $destination_dir
            echo -e "$(color cb 添加) $target_dir [ $(color cb ✔) ]" | _printf
        fi
    done
    rm -rf $temp_dir
}

# 创建插件保存目录
destination_dir="package/A"
[ -d $destination_dir ] || mkdir -p $destination_dir

color cy "添加&替换插件"

# 添加额外插件
git_clone https://github.com/kongfl888/luci-app-adguardhome
clone_all https://github.com/sirpdboy/luci-app-ddns-go

clone_all lua https://github.com/sbwml/luci-app-alist
clone_all v5-lua https://github.com/sbwml/luci-app-mosdns
git_clone https://github.com/sbwml/packages_lang_golang golang

git_clone lede https://github.com/pymumu/luci-app-smartdns
git_clone https://github.com/pymumu/openwrt-smartdns smartdns

git_clone https://github.com/ximiTech/luci-app-msd_lite
git_clone https://github.com/ximiTech/msd_lite

clone_all https://github.com/linkease/istore-ui
clone_all https://github.com/linkease/istore luci

# 科学上网插件
clone_all https://github.com/fw876/helloworld
clone_all https://github.com/xiaorouji/openwrt-passwall-packages
clone_all https://github.com/xiaorouji/openwrt-passwall
clone_all https://github.com/xiaorouji/openwrt-passwall2
clone_dir https://github.com/vernesong/OpenClash luci-app-openclash

# Themes
git_clone 18.06 https://github.com/kiddin9/luci-theme-edge
git_clone 18.06 https://github.com/jerrykuku/luci-theme-argon
git_clone 18.06 https://github.com/jerrykuku/luci-app-argon-config
clone_dir https://github.com/xiaoqingfengATGH/luci-theme-infinityfreedom luci-theme-infinityfreedom-ng
clone_dir https://github.com/haiibo/packages luci-theme-opentomcat

# 晶晨宝盒
clone_all https://github.com/ophub/luci-app-amlogic
sed -i "s|firmware_repo.*|firmware_repo 'https://github.com/$GITHUB_REPOSITORY'|g" $destination_dir/luci-app-amlogic/root/etc/config/amlogic
# sed -i "s|kernel_path.*|kernel_path 'https://github.com/ophub/kernel'|g" $destination_dir/luci-app-amlogic/root/etc/config/amlogic
sed -i "s|ARMv8|$RELEASE_TAG|g" $destination_dir/luci-app-amlogic/root/etc/config/amlogic

# 开始加载个人设置
BEGIN_TIME=$(date '+%H:%M:%S')

# 修改默认IP
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 更改默认 Shell 为 zsh
# sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd

# TTYD 免登录
sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

# 设置 root 用户密码为空
# sed -i '/CYXluq4wUazHjmCDBCqXF/d' package/lean/default-settings/files/zzz-default-settings 

# 更改 Argon 主题背景
cp -f $GITHUB_WORKSPACE/images/bg1.jpg feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg

# x86 型号只显示 CPU 型号
sed -i 's/${g}.*/${a}${b}${c}${d}${e}${f}${hydrid}/g' package/lean/autocore/files/x86/autocore
sed -i "s/'C'/'Core '/g; s/'T '/'Thread '/g" package/lean/autocore/files/x86/autocore

# 取消主题默认设置
# find $destination_dir/luci-theme-*/ -type f -name '*luci-theme-*' -print -exec sed -i '/set luci.main.mediaurlbase/d' {} \;

# 调整 Docker 到 服务 菜单
sed -i 's/"admin"/"admin", "services"/g' feeds/luci/applications/luci-app-dockerman/luasrc/controller/*.lua
sed -i 's/"admin"/"admin", "services"/g; s/admin\//admin\/services\//g' feeds/luci/applications/luci-app-dockerman/luasrc/model/cbi/dockerman/*.lua
sed -i 's/admin\//admin\/services\//g' feeds/luci/applications/luci-app-dockerman/luasrc/view/dockerman/*.htm
sed -i 's|admin\\|admin\\/services\\|g' feeds/luci/applications/luci-app-dockerman/luasrc/view/dockerman/container.htm

# 调整 ZeroTier 到 服务 菜单
# sed -i 's/vpn/services/g; s/VPN/Services/g' feeds/luci/applications/luci-app-zerotier/luasrc/controller/zerotier.lua
# sed -i 's/vpn/services/g' feeds/luci/applications/luci-app-zerotier/luasrc/view/zerotier/zerotier_status.htm

# 添加防火墙规则
# sed -i '/PREROUTING/s/^#//' package/lean/default-settings/files/zzz-default-settings

# 取消对 samba4 的菜单调整
# sed -i '/samba4/s/^/#/' package/lean/default-settings/files/zzz-default-settings

# 修复 Makefile 路径
find $destination_dir/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i \
    -e 's?\.\./\.\./luci.mk?$(TOPDIR)/feeds/luci/luci.mk?' \
    -e 's?include \.\./\.\./\(lang\|devel\)?include $(TOPDIR)/feeds/packages/\1?' {}

# 转换插件语言翻译
for e in $(ls -d $destination_dir/luci-*/po feeds/luci/applications/luci-*/po); do
    if [[ -d $e/zh-cn && ! -d $e/zh_Hans ]]; then
        ln -s zh-cn $e/zh_Hans 2>/dev/null
    elif [[ -d $e/zh_Hans && ! -d $e/zh-cn ]]; then
        ln -s zh_Hans $e/zh-cn 2>/dev/null
    fi
done
status "加载个人设置"

# 开始下载openchash运行内核
[ $CLASH_KERNEL ] && {
    BEGIN_TIME=$(date '+%H:%M:%S')
    chmod +x $GITHUB_WORKSPACE/scripts/preset-clash-core.sh
    $GITHUB_WORKSPACE/scripts/preset-clash-core.sh $CLASH_KERNEL
    status "下载openchash运行内核"
}

# 开始下载zsh终端工具
BEGIN_TIME=$(date '+%H:%M:%S')
chmod +x $GITHUB_WORKSPACE/scripts/preset-terminal-tools.sh
$GITHUB_WORKSPACE/scripts/preset-terminal-tools.sh
status "下载zsh终端工具"

# 开始下载adguardhome运行内核
[ $CLASH_KERNEL ] && {
    BEGIN_TIME=$(date '+%H:%M:%S')
    chmod +x $GITHUB_WORKSPACE/scripts/preset-adguard-core.sh
    $GITHUB_WORKSPACE/scripts/preset-adguard-core.sh $CLASH_KERNEL
    status "下载adguardhome运行内核"
}

# 开始更新配置文件
BEGIN_TIME=$(date '+%H:%M:%S')
make defconfig 1>/dev/null 2>&1
status "更新配置文件"

echo -e "$(color cy 当前编译机型) $(color cb $SOURCE_REPO-${REPO_BRANCH#*-}-$DEVICE_TARGET-$KERNEL_VERSION)"

echo -e "\e[1;35m脚本运行完成！\e[0m"
