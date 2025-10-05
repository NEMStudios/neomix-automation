#!/bin/bash
set -eo pipefail

APP_NAME="NVIDIA GPU Drivers"
ROCKY_VERSION="9"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}====================================="
echo -e "\033[1;32mBASE MEDIA, PLE - Rocky Linux ${ROCKY_VERSION}.* Install Script"
echo -e "\033[1;32mInstalling $APP_NAME"
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

install_development_tools() {
    log "安装开发工具和内核组件..."
    run_dnf install epel-release -y
    run_dnf groupinstall "Development Tools" -y
    run_dnf install kernel-devel dkms -y
}

add_cuda_repository() {
    log "配置NVIDIA软件仓库..."
    run_dnf config-manager --add-repo "http://developer.download.nvidia.com/compute/cuda/repos/rhel9/$(uname -i)/cuda-rhel9.repo"
}

install_dependencies() {
    local current_kernel="$(uname -r)"
    log "安装依赖组件..."
    run_dnf install \
        "kernel-headers-${current_kernel}" \
        "kernel-devel-${current_kernel}" \
        tar bzip2 make automake gcc gcc-c++ \
        pciutils elfutils-libelf-devel \
        libglvnd-opengl libglvnd-glx libglvnd-devel \
        acpid pkgconf -y
}

install_nvidia_driver() {
    log "正在安装NVIDIA显卡驱动..."
    run_dnf module install nvidia-driver:latest-dkms -y
    log "如果是Secure Boot系统，接下来将提示设置MOK密码..."
}

check_secure_boot() {
    if [ -d /sys/firmware/efi ] && sudo mokutil --sb-state | grep -q "SecureBoot enabled"; then
        log "检测到Secure Boot已启用，需要导入MOK密钥"
        return 0
    fi
    return 1
}

handle_secure_boot() {
    log "正在检查MOK密钥文件..."
    if [ ! -f /var/lib/dkms/mok.pub ]; then
        error_exit "未找到MOK密钥文件，请先完成驱动安装"
    fi

    log "处理Secure Boot要求..."
    if ! sudo mokutil --import /var/lib/dkms/mok.pub; then
        error_exit "无法导入MOK密钥 - Secure Boot需要手动注册密钥"
    fi

    echo -e "${YELLOW}\n重要提示："
    echo -e "1. 系统将提示您设置MOK密钥密码（用于下次启动时验证）"
    echo -e "2. 重启后选择『Enroll MOK』→『Continue』→『Yes』输入密码完成注册"
    echo -e "3. 然后选择『reboot』继续启动系统${NC}"

    read -rp "是否继续？[y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        error_exit "用户取消操作"
    fi
}

configure_kernel_params() {
    log "优化内核参数配置..."
    if ! sudo grubby --args="nouveau.modeset=0 rd.driver.blacklist=nouveau" --update-kernel=ALL; then
        error_exit "内核参数配置失败"
    fi
}

prepare_for_reboot() {
    echo -e "\n${GREEN}✅ $APP_NAME 安装完成！${NC}"
    if check_secure_boot; then
        echo -e "${YELLOW}请记住您设置的MOK密码，重启后需要完成密钥注册${NC}"
    fi

    echo -e "${YELLOW}系统需要重启以完成安装，将在10秒后自动重启...${NC}"
    echo -e "${YELLOW}按 Ctrl+C 取消${NC}"
    sleep 10
    sudo reboot
}

main() {
    check_sudo

    # Phase 1: Driver installation
    install_development_tools
    add_cuda_repository
    install_dependencies
    install_nvidia_driver

    # Phase 2: Secure Boot handling (after driver generates MOK key)
    if check_secure_boot; then
        handle_secure_boot
    fi

    # Phase 3: Final system configuration
    configure_kernel_params
    prepare_for_reboot
}

main "$@"
