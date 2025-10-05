#!/bin/bash
set -eo pipefail

APP_NAME="Repolist && System"
ROCKY_VERSION="9"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}====================================="
echo -e "\033[1;32mBASE MEDIA, PLE - Rocky Linux ${ROCKY_VERSION}.* Install Script"
echo -e "\033[1;32mInstalling and Updating $APP_NAME"
echo -e "${GREEN}=====================================${NC}"

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

install_epel_rpm_fusion() {
    log "启用 EPEL 仓库和 RPM Fusion 仓库..."
    run_dnf install epel-release -y
    run_dnf config-manager --set-enabled epel-testing -y
    run_dnf install "https://download1.rpmfusion.org/free/el/rpmfusion-free-release-${ROCKY_VERSION}.noarch.rpm" -y
    run_dnf install "https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-${ROCKY_VERSION}.noarch.rpm" -y
    run_dnf makecache

    log "验证 EPEL仓库 和 RPM Fusion仓库..."
    run_dnf repolist
}

change_repo_to_aliyun() {
    log "切换到国内镜像源..."
    sudo mkdir -p /etc/yum.repos.d/backup || error_exit "Failed to create backup directory"
    sudo cp /etc/yum.repos.d/rocky*.repo /etc/yum.repos.d/backup/ || error_exit "Failed to backup repos"

    if ! sudo sed -i.bak \
        -e 's|^mirrorlist=|#mirrorlist=|g' \
        -e 's|^#baseurl=http://dl.rockylinux.org/$contentdir|baseurl=https://mirrors.aliyun.com/rockylinux|g' \
        /etc/yum.repos.d/rocky*.repo; then
        error_exit "Failed to modify repository files"
    fi

    log "切换到阿里云镜像源，正在准备更新系统..."
    run_dnf clean all
    sudo rm -rf /var/cache/yum || warn "Failed to clear yum cache"
    run_dnf makecache
    run_dnf update -y
    run_dnf autoremove -y
    run_dnf clean all
    run_dnf makecache

    log "验证切换后的 EPEL仓库 和 RPM Fusion仓库..."
    run_dnf repolist
}

post_install_or_update() {
    echo -e "\n${GREEN}✅ $APP_NAME 安装与配置完成！${NC}"
    echo -e "\n${YELLOW}提示: 如果有内核更新建议重启系统。${NC}"
    read -rp "是否现在重启？[y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}系统将在10秒后重启...${NC}"
        echo -e "${YELLOW}按 Ctrl+C 取消${NC}"
        sleep 10
        sudo reboot
    fi
}

main() {
    check_sudo
    echo -e "${GREEN}开始启动EPEL仓库 和 RPM Fusion仓库，并更新系统...${NC}"
    install_epel_rpm_fusion
    change_repo_to_aliyun
    post_install_or_update
}

main "$@"
