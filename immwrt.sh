#!/bin/bash

# 打包toolchain目录
if [[ "$REBUILD_TOOLCHAIN" = 'true' ]]; then
    cd $OPENWRT_PATH
    sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
    if [[ -d ".ccache" && $(du -s .ccache | cut -f1) -gt 0 ]]; then
        echo "🔍 缓存目录大小:"
        du -h --max-depth=1 .ccache
        ccache_dir=".ccache"
    fi
    echo "📦 工具链目录大小:"
    du -h --max-depth=1 staging_dir
    tar -I zstdmt -cf "$GITHUB_WORKSPACE/output/$CACHE_NAME.tzst" staging_dir/host* staging_dir/tool* $ccache_dir
    echo "📁 输出目录内容:"
    ls -lh "$GITHUB_WORKSPACE/output"
    if [[ ! -e "$GITHUB_WORKSPACE/output/$CACHE_NAME.tzst" ]]; then
        echo "❌ 工具链打包失败!"
        exit 1
    fi
    echo "✅ 工具链打包完成"
    exit 0
fi

# 创建toolchain缓存保存目录
[ -d "$GITHUB_WORKSPACE/output" ] || mkdir "$GITHUB_WORKSPACE/output"

# 颜色输出
color() {
    case "$1" in
        cr) echo -e "\e[1;31m${2}\e[0m" ;;  # 红色
        cg) echo -e "\e[1;32m${2}\e[0m" ;;  # 绿色
        cy) echo -e "\e[1;33m${2}\e[0m" ;;  # 黄色
        cb) echo -e "\e[1;34m${2}\e[0m" ;;  # 蓝色
        cp) echo -e "\e[1;35m${2}\e[0m" ;;  # 紫色
        cc) echo -e "\e[1;36m${2}\e[0m" ;;  # 青色
        cw) echo -e "\e[1;37m${2}\e[0m" ;;  # 白色
    esac
}

# 状态显示和时间统计
status_info() {
    local task_name="$1" begin_time=$(date +%s) exit_code time_info
    shift
    "$@"
    exit_code=$?
    [[ "$exit_code" -eq 99 ]] && return 0
    if [[ -n "$begin_time" ]]; then
        time_info="==> 用时 $(($(date +%s) - begin_time)) 秒"
    else
        time_info=""
    fi
    if [[ "$exit_code" -eq 0 ]]; then
        printf "%s %-52s %s %s %s %s %s %s %s\n" \
        $(color cy "⏳ $task_name") [ $(color cg ✔) ] $(color cw "$time_info")
    else
        printf "%s %-52s %s %s %s %s %s %s %s\n" \
        $(color cy "⏳ $task_name") [ $(color cr ✖) ] $(color cw "$time_info")
    fi
}

# 查找目录
find_dir() {
    find $1 -maxdepth 3 -type d -name "$2" -print -quit 2>/dev/null
}

# 打印信息
print_info() {
    printf "%s %-40s %s %s %s\n" "$1" "$2" "$3" "$4" "$5"
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
    target_dir="${1:-${repo_url##*/}}"
    git clone -q $branch --depth=1 "$repo_url" "$target_dir" 2>/dev/null || {
        print_info $(color cr 拉取) "$repo_url" [ $(color cr ✖) ]
        return 1
    }
    rm -rf $target_dir/{.git*,README*.md,LICENSE}
    current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
    if [[ -d "$current_dir" ]]; then
        rm -rf "$current_dir"
        mv -f "$target_dir" "${current_dir%/*}"
        print_info $(color cg 替换) "$target_dir" [ $(color cg ✔) ]
    else
        mv -f "$target_dir" "$destination_dir"
        print_info $(color cb 添加) "$target_dir" [ $(color cb ✔) ]
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
    git clone -q $branch --depth=1 "$repo_url" "$temp_dir" 2>/dev/null || {
        print_info $(color cr 拉取) "$repo_url" [ $(color cr ✖) ]
        rm -rf "$temp_dir"
        return 1
    }
    local target_dir source_dir current_dir
    for target_dir in "$@"; do
        source_dir=$(find_dir "$temp_dir" "$target_dir")
        [[ -d "$source_dir" ]] || \
        source_dir=$(find "$temp_dir" -maxdepth 4 -type d -name "$target_dir" -print -quit) && \
        [[ -d "$source_dir" ]] || {
            print_info $(color cr 查找) "$target_dir" [ $(color cr ✖) ]
            continue
        }
        current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
        if [[ -d "$current_dir" ]]; then
            rm -rf "$current_dir"
            mv -f "$source_dir" "${current_dir%/*}"
            print_info $(color cg 替换) "$target_dir" [ $(color cg ✔) ]
        else
            mv -f "$source_dir" "$destination_dir"
            print_info $(color cb 添加) "$target_dir" [ $(color cb ✔) ]
        fi
    done
    rm -rf "$temp_dir"
}

# 添加源仓库内的所有子目录
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
    git clone -q $branch --depth=1 "$repo_url" "$temp_dir" 2>/dev/null || {
        print_info $(color cr 拉取) "$repo_url" [ $(color cr ✖) ]
        rm -rf "$temp_dir"
        return 1
    }
    process_dir() {
        while IFS= read -r source_dir; do
            local target_dir=$(basename "$source_dir")
            local current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
            if [[ -d "$current_dir" ]]; then
                rm -rf "$current_dir"
                mv -f "$source_dir" "${current_dir%/*}"
                print_info $(color cg 替换) "$target_dir" [ $(color cg ✔) ]
            else
                mv -f "$source_dir" "$destination_dir"
                print_info $(color cb 添加) "$target_dir" [ $(color cb ✔) ]
            fi
        done < <(find "$1" -maxdepth 1 -mindepth 1 -type d ! -name '.*')
    }
    if [[ $# -eq 0 ]]; then
        process_dir "$temp_dir"
    else
        for dir_name in "$@"; do
            [[ -d "$temp_dir/$dir_name" ]] && process_dir "$temp_dir/$dir_name" || \
            print_info $(color cr 目录) "$dir_name" [ $(color cr ✖) ]
        done
    fi
    rm -rf "$temp_dir"
}

# 主流程
main() {
    echo "$(color cp "🚀 开始运行自定义脚本")"
    echo "========================================"

    # 拉取编译源码
    status_info "拉取编译源码" clone_source_code

    # 设置环境变量
    status_info "设置环境变量" set_variable_values

    # 下载部署toolchain缓存
    status_info "下载部署toolchain缓存" download_toolchain

    # 更新&安装插件
    status_info "更新&安装插件" update_install_feeds

    # 添加额外插件
    status_info "添加额外插件" add_custom_packages

    # 加载个人设置
    status_info "加载个人设置" apply_custom_settings

    # 更新配置文件
    status_info "更新配置文件" update_config_file

    # 下载openclash运行内核
    status_info "下载openclash运行内核" preset_openclash_core

    # 下载zsh终端工具
    status_info "下载zsh终端工具" preset_shell_tools

    # 显示编译信息
    show_build_info

    echo "$(color cp "✅ 自定义脚本运行完成")"
    echo "========================================"
}

# 拉取编译源码
clone_source_code() {
    # 设置编译源码与分支
    REPO_URL="https://github.com/immortalwrt/immortalwrt"
    echo "REPO_URL=$REPO_URL" >>$GITHUB_ENV
    REPO_BRANCH="openwrt-24.10"
    echo "REPO_BRANCH=$REPO_BRANCH" >>$GITHUB_ENV

    # 拉取编译源码
    git clone -q -b "$REPO_BRANCH" --single-branch "$REPO_URL" openwrt
    [ -d openwrt ] && cd openwrt || exit
    echo "OPENWRT_PATH=$PWD" >>$GITHUB_ENV
}

# 设置环境变量
set_variable_values() {
    local TARGET_NAME SUBTARGET_NAME KERNEL KERNEL_FILE TOOLS_HASH

    # 源仓库与分支
    SOURCE_REPO=$(basename "$REPO_URL")
    echo "SOURCE_REPO=$SOURCE_REPO" >>$GITHUB_ENV
    echo "LITE_BRANCH=${REPO_BRANCH#*-}" >>$GITHUB_ENV

    # 平台架构
    TARGET_NAME=$(grep -oP "^CONFIG_TARGET_\K[a-z0-9]+(?==y)" "$GITHUB_WORKSPACE/$CONFIG_FILE")
    SUBTARGET_NAME=$(grep -oP "^CONFIG_TARGET_${TARGET_NAME}_\K[a-z0-9]+(?==y)" "$GITHUB_WORKSPACE/$CONFIG_FILE")
    DEVICE_TARGET="$TARGET_NAME-$SUBTARGET_NAME"
    echo "DEVICE_TARGET=$DEVICE_TARGET" >>$GITHUB_ENV

    # 内核版本
    KERNEL=$(grep -oP 'KERNEL_PATCHVER:=\K[\d\.]+' "target/linux/$TARGET_NAME/Makefile")
    KERNEL_FILE="include/kernel-$KERNEL"
    [ -e "$KERNEL_FILE" ] || KERNEL_FILE="target/linux/generic/kernel-$KERNEL"
    KERNEL_VERSION=$(grep -oP 'LINUX_KERNEL_HASH-\K[\d\.]+' "$KERNEL_FILE")
    echo "KERNEL_VERSION=$KERNEL_VERSION" >>$GITHUB_ENV

    # toolchain缓存文件名
    TOOLS_HASH=$(git log -1 --pretty=format:"%h" tools toolchain)
    CACHE_NAME="$SOURCE_REPO-${REPO_BRANCH#*-}-$DEVICE_TARGET-cache-$TOOLS_HASH"
    echo "CACHE_NAME=$CACHE_NAME" >>$GITHUB_ENV

    # 源码更新信息
    echo "COMMIT_AUTHOR=$(git show -s --date=short --format="作者: %an")" >>$GITHUB_ENV
    echo "COMMIT_DATE=$(git show -s --date=short --format="时间: %ci")" >>$GITHUB_ENV
    echo "COMMIT_MESSAGE=$(git show -s --date=short --format="内容: %s")" >>$GITHUB_ENV
    echo "COMMIT_HASH=$(git show -s --date=short --format="hash: %H")" >>$GITHUB_ENV
}

# 下载部署toolchain缓存
download_toolchain() {
    local cache_xa cache_xc
    if [[ "$TOOLCHAIN" = 'true' ]]; then
        cache_xa=$(curl -sL "https://api.github.com/repos/$GITHUB_REPOSITORY/releases" | awk -F '"' '/download_url/{print $4}' | grep "$CACHE_NAME")
        cache_xc=$(curl -sL "https://api.github.com/repos/haiibo/toolchain-cache/releases" | awk -F '"' '/download_url/{print $4}' | grep "$CACHE_NAME")
        if [[ "$cache_xa" || "$cache_xc" ]]; then
            wget -qc -t=3 "${cache_xa:-$cache_xc}"
            if [ -e *.tzst ]; then
                tar -I unzstd -xf *.tzst || tar -xf *.tzst
                [ "$cache_xa" ] || (cp *.tzst $GITHUB_WORKSPACE/output && echo "OUTPUT_RELEASE=true" >>$GITHUB_ENV)
                [ -d staging_dir ] && sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
            fi
        else
            echo "REBUILD_TOOLCHAIN=true" >>$GITHUB_ENV
            echo "⚠️ 未找到最新工具链"
            return 99
        fi
    else
        echo "REBUILD_TOOLCHAIN=true" >>$GITHUB_ENV
        return 99
    fi
}

# 更新&安装插件
update_install_feeds() {
    ./scripts/feeds update -a 1>/dev/null 2>&1
    ./scripts/feeds install -a 1>/dev/null 2>&1
}

# 添加额外插件
add_custom_packages() {
    echo "📦 添加额外插件..."

    # 创建插件保存目录
    destination_dir="package/A"
    [ -d "$destination_dir" ] || mkdir -p "$destination_dir"

    # 基础插件
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
    clone_dir https://github.com/sbwml/openwrt_helloworld xray-core

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

    # 修复Makefile路径
    find "$destination_dir" -type f -name "Makefile" | xargs sed -i \
        -e 's?\.\./\.\./\(lang\|devel\)?$(TOPDIR)/feeds/packages/\1?' \
        -e 's?\.\./\.\./luci.mk?$(TOPDIR)/feeds/luci/luci.mk?'

    # 转换插件语言翻译
    for e in $(ls -d $destination_dir/luci-*/po feeds/luci/applications/luci-*/po); do
        if [[ -d $e/zh-cn && ! -d $e/zh_Hans ]]; then
            ln -s zh-cn $e/zh_Hans 2>/dev/null
        elif [[ -d $e/zh_Hans && ! -d $e/zh-cn ]]; then
            ln -s zh_Hans $e/zh-cn 2>/dev/null
        fi
    done
}

# 加载个人设置
apply_custom_settings() {
    local drv_path pbuf_path

    [ -e "$GITHUB_WORKSPACE/files" ] && mv "$GITHUB_WORKSPACE/files" files

    # 设置固件rootfs大小
    if [ "$PART_SIZE" ]; then
        sed -i '/ROOTFS_PARTSIZE/d' "$GITHUB_WORKSPACE/$CONFIG_FILE"
        echo "CONFIG_TARGET_ROOTFS_PARTSIZE=$PART_SIZE" >>"$GITHUB_WORKSPACE/$CONFIG_FILE"
    fi

    # 修改默认ip地址
    [ "$IP_ADDRESS" ] && sed -i '/lan) ipad/s/".*"/"'"$IP_ADDRESS"'"/' package/base-files/files/bin/config_generate

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

    # 临时修复rust资源失效(编译时间变长)
    sed -i 's/download-ci-llvm=true/download-ci-llvm=false/g' feeds/packages/lang/rust/Makefile

    # 修改qca-nss-drv启动顺序
    drv_path="feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
    if [ -f "$drv_path" ]; then
        sed -i 's/START=.*/START=85/g' "$drv_path"
    fi

    # 修改qca-nss-pbuf启动顺序
    pbuf_path="package/kernel/mac80211/files/qca-nss-pbuf.init"
    if [ -f "$pbuf_path" ]; then
        sed -i 's/START=.*/START=86/g' "$pbuf_path"
    fi

    # 移除attendedsysupgrade
    find "feeds/luci/collections" -name "Makefile" | while read -r makefile; do
        if grep -q "luci-app-attendedsysupgrade" "$makefile"; then
            sed -i "/luci-app-attendedsysupgrade/d" "$makefile"
        fi
    done
}

# 更新配置文件
update_config_file() {
    [ -e "$GITHUB_WORKSPACE/$CONFIG_FILE" ] && cp -f "$GITHUB_WORKSPACE/$CONFIG_FILE" .config
    make defconfig 1>/dev/null 2>&1
}

# 检测指令集架构
detect_openwrt_arch() {
    local config="${1:-.config}"
    local arch_pkgs=$(grep '^CONFIG_TARGET_ARCH_PACKAGES=' "$config" | cut -d'"' -f2)
    [ -n "$arch_pkgs" ] || return 1
    case "$arch_pkgs" in
        x86_64) echo "amd64" ;; i386*) echo "386" ;; aarch64*) echo "arm64" ;;
        arm_cortex-a*) echo "armv7" ;; arm_arm1176*|arm_mpcore*) echo "armv6" ;;
        arm_arm926*|arm_fa526|arm*xscale) echo "armv5" ;;
        mips64el_*) echo "mips64le" ;; mips64_*) echo "mips64" ;;
        mipsel_*) echo "mipsle" ;; mips_*) echo "mips" ;;
        riscv64*) echo "riscv64" ;; loongarch64*) echo "loong64" ;;
        powerpc64_*) echo "ppc64" ;; powerpc_*) echo "ppc" ;;
        arc_*) echo "arc" ;; *) echo "unknown" ;;
    esac
}

# 下载openclash运行内核
preset_openclash_core() {
    CPU_ARCH=$(detect_openwrt_arch ".config")
    if [[ "$CPU_ARCH" =~ ^(amd64|arm64|armv7|armv6|armv5|386|mips64|mips64le|riscv64)$ ]] && grep -q "luci-app-openclash=y" .config; then
        chmod +x $GITHUB_WORKSPACE/scripts/preset-clash-core.sh
        $GITHUB_WORKSPACE/scripts/preset-clash-core.sh $CPU_ARCH
    else
        return 99
    fi
}

# 下载zsh终端工具
preset_shell_tools() {
    if grep -q "zsh=y" .config; then
        chmod +x $GITHUB_WORKSPACE/scripts/preset-terminal-tools.sh
        $GITHUB_WORKSPACE/scripts/preset-terminal-tools.sh
    else
        return 99
    fi
}

show_build_info() {
    echo -e "$(color cy "📊 当前编译信息")"
    echo "========================================"
    echo "🔷 固件源码: $(color cc "$SOURCE_REPO")"
    echo "🔷 源码分支: $(color cc "$REPO_BRANCH")"
    echo "🔷 目标设备: $(color cc "$DEVICE_TARGET")"
    echo "🔷 内核版本: $(color cc "$KERNEL_VERSION")"
    echo "🔷 编译架构: $(color cc "$CPU_ARCH")"
    echo "========================================"
}

main "$@"
