#!/bin/bash
set -eo pipefail

APP_NAME="Python Virtual Environments"
ROCKY_VERSION="9"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}====================================="
echo -e "\033[1;32mBASE MEDIA, PLE - Rocky Linux ${ROCKY_VERSION}.* Setup Script"
echo -e "\033[1;32mCreating $APP_NAME"
echo -e "${GREEN}=====================================${NC}"

# Global variables
PYTHON_VERSIONS=("3.7" "3.9" "3.10" "3.11")
PYTHON_BIN_DIR="/opt/python/bin"
USER_HOME="$(getent passwd ${SUDO_USER:-$(whoami)} | cut -d: -f6)"
DEV_ROOT="${USER_HOME}/Development"
VENVS_ROOT="${DEV_ROOT}/0_Config/virtual_envs"

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

check_requirements() {
    if [[ ! -d "$PYTHON_BIN_DIR" ]]; then
        error_exit "Python 安装目录不存在: $PYTHON_BIN_DIR"
    fi
}

setup_venvs_directory() {
    log "创建虚拟环境目录: $VENVS_ROOT"
    mkdir -p "$VENVS_ROOT" || error_exit "无法创建虚拟环境目录"
}

create_virtualenv() {
    local version="$1"
    local pybin="${PYTHON_BIN_DIR}/python${version}"
    local venv_name="venv${version//./}"
    local venv_path="${VENVS_ROOT}/${venv_name}"

    if [[ ! -x "$pybin" ]]; then
        warn "跳过 Python ${version}: 未找到 $pybin"
        return
    fi

    if [[ -d "$venv_path" ]]; then
        warn "虚拟环境 ${venv_name} 已存在，跳过创建"
        return
    fi

    log "为 Python ${version} 创建虚拟环境: ${venv_path}"
    "$pybin" -m venv "$venv_path" || error_exit "创建虚拟环境失败: Python ${version}"

    log "验证虚拟环境: ${venv_name}"
    if ! source "${venv_path}/bin/activate" && python -V; then
        error_exit "虚拟环境验证失败: ${venv_name}"
    fi
    deactivate
}

create_symlinks() {
    log "创建虚拟环境快捷方式到 ~/.venvs"
    mkdir -p "${USER_HOME}/.venvs"
    for venv in "${VENVS_ROOT}"/*; do
        local venv_name=$(basename "$venv")
        ln -sf "$venv" "${USER_HOME}/.venvs/${venv_name}" || warn "无法创建快捷方式: ${venv_name}"
    done
}

post_install() {
    echo -e "\n${GREEN}✅ 虚拟环境创建完成${NC}"
    echo -e "\n${YELLOW}使用方法:${NC}"
    echo -e "1. 激活虚拟环境:"
    echo -e "   source ~/.venvs/venv37/bin/activate"
    echo -e "2. 检查 Python 版本:"
    echo -e "   python -V"
    echo -e "3. 退出虚拟环境:"
    echo -e "   deactivate"
    echo -e "\n${YELLOW}虚拟环境位置:${NC}"
    echo -e "   ${VENVS_ROOT}/"
}

main() {
    check_sudo
    check_requirements
    setup_venvs_directory

    for version in "${PYTHON_VERSIONS[@]}"; do
        create_virtualenv "$version"
    done

    create_symlinks
    post_install
}

main "$@"
