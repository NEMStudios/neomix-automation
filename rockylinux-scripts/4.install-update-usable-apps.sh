#!/bin/bash
set -eo pipefail

APP_NAME="Fastfetch, Lolcat & Other Usable Apps"
ROCKY_VERSION="9"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}====================================="
echo -e "\033[1;32mBASE MEDIA, PLE - Rocky Linux ${ROCKY_VERSION}.* Install Script"
echo -e "\033[1;32mInstalling $APP_NAME"
echo -e "${GREEN}=====================================${NC}"

# Global variables
USER_HOME="$(getent passwd ${SUDO_USER:-$(whoami)} | cut -d: -f6)"
TEMPLATES="${USER_HOME}/Templates"

check_sudo() {
    if ! sudo -v; then
        error_exit "This script requires sudo privileges."
    fi
}

log() {
    echo -e "${GREEN}[$(date +'%T')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARN $(date +'%T')] $1${NC}"
}

error_exit() {
    echo -e "${RED}错误: $1${NC}" >&2
    exit 1
}

run_dnf() {
    if ! sudo dnf "$@" ; then
        error_exit "Failed to run: dnf $*"
    fi
}

install_ibus_libpinyin() {
    log "安装 IBus ibus-libpinyin..."
    run_dnf install -y ibus-libpinyin

    log "启动 IBus 服务..."
    if ! ibus-daemon -drx; then
        warn "Failed to start ibus-daemon"
    fi

    log "请手动运行 ibus-setup 配置输入法"
}

install_fastfetch() {
    log "安装 Fastfetch 依赖..."
    run_dnf install -y git cmake gcc-c++ pciutils-devel vulkan-devel wayland-devel

    log "编译安装 Fastfetch..."
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"

    git clone --depth=1 https://gitee.com/mirrors/fastfetch.git || \
        error_exit "Failed to clone fastfetch"

    cd fastfetch
    mkdir -p build && cd build
    cmake .. || error_exit "CMake configuration failed"
    make -j"$(nproc)" || error_exit "Build failed"
    sudo make install || error_exit "Installation failed"

    log "验证安装..."
    fastfetch --version || warn "Fastfetch 安装验证失败"

    cd ~
    rm -rf "$temp_dir"
}

install_lolcat() {
    log "安装 Lolcat 依赖..."
    run_dnf install -y ruby

    log "通过 gem 安装 Lolcat..."
    if ! sudo gem install lolcat; then
        warn "Failed to install lolcat via gem"
        run_dnf install -y rubygem-lolcat  # Fallback to package manager
    fi
}

install_edge_stable() {
    log "添加 Microsoft Edge 仓库..."
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc || \
        error_exit "Failed to import Microsoft GPG key"

    sudo dnf config-manager --add-repo https://packages.microsoft.com/yumrepos/edge || \
        error_exit "Failed to add Edge repository"

    log "安装 Microsoft Edge..."
    run_dnf install -y microsoft-edge-stable

    log "设置 Edge 为默认浏览器..."
    if ! xdg-settings set default-web-browser microsoft-edge.desktop; then
        warn "Failed to set Edge as default browser"
    fi
}

remove_firefox() {
    if rpm -q firefox &>/dev/null; then
        log "卸载 Firefox..."
        run_dnf remove -y firefox
        rm -rf ~/.mozilla
    else
        log "Firefox 未安装，跳过卸载"
    fi
}

install_utilities() {
    log "安装系统工具..."
    local packages=(
        bleachbit htop git-lfs
        zip unzip tar xz
        wget speedtest-cli fzf
    )
    run_dnf install -y "${packages[@]}"
}

install_kvm(){
    log "安装 KVM & virt-manager..."
    run_dnf install -y qemu-kvm libvirt virt-install virt-viewer bridge-utils libguestfs-tools
    sudo systemctl enable --now libvirtd
    run_dnf install -y virt-manager
    sudo usermod -aG libvirt $(whoami)
    newgrp libvirt  # 刷新用户组（或重新登录）
}

show_results() {
    log "展示系统信息："
    if command -v fastfetch &>/dev/null; then
        fastfetch -l redhat | lolcat || fastfetch -l redhat
    else
        warn "没有找到可用的系统信息工具"
    fi
}

post_install() {
    echo -e "\n${GREEN}✅ $APP_NAME 安装完成${NC}"
    echo -e "\n${YELLOW}建议操作：${NC}"
    echo -e "1. 运行 ibus-setup 配置输入法"
    echo -e "2. 检查 Edge 浏览器是否为默认浏览器"

    read -rp "是否现在重启系统？[y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}系统将在10秒后重启...${NC}"
        sleep 10
        sudo reboot
    fi
}

main() {
    check_sudo
    install_ibus_libpinyin
    install_fastfetch
    install_lolcat
    install_edge_stable
    remove_firefox
    install_utilities
    show_results
    post_install
}

main "$@"
