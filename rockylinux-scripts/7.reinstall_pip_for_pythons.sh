#!/bin/bash
set -eo pipefail

APP_NAME="Python Pip Reinstaller"
ROCKY_VERSION="9"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}====================================="
echo -e "\033[1;32mBASE MEDIA, PLE - Rocky Linux ${ROCKY_VERSION}.* Setup Script"
echo -e "\033[1;32mReinstalling $APP_NAME"
echo -e "${GREEN}=====================================${NC}"

# Global variables
PYTHON_VERSIONS=("3.7" "3.9" "3.10" "3.11")
PYTHON_BIN_DIR="/opt/python/bin"
GET_PIP_BASE_URL="https://bootstrap.pypa.io"

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

check_python_binary() {
    local version="$1"
    local pybin="${PYTHON_BIN_DIR}/python${version}"

    if [[ ! -x "$pybin" ]]; then
        warn "Python ${version} 未安装: ${pybin} 不存在"
        return 1
    fi
    return 0
}

uninstall_existing_pip() {
    local pybin="$1"
    local version="$2"

    if "$pybin" -m pip --version &>/dev/null; then
        log "卸载 Python ${version} 的旧 pip..."
        if ! "$pybin" -m pip uninstall -y pip; then
            warn "Python ${version} 的 pip 卸载失败 - 强制清除"
            rm -rf "$(dirname "$pybin")/../lib/python${version%.*}/site-packages/pip"*
        fi
    fi
}

install_with_ensurepip() {
    local pybin="$1"
    local version="$2"

    log "尝试使用 ensurepip 安装..."
    if "$pybin" -m ensurepip --upgrade &>/dev/null; then
        log "✅ Python ${version} 成功使用 ensurepip 安装 pip"
        return 0
    fi
    return 1
}

install_with_get_pip() {
    local pybin="$1"
    local version="$2"
    local major_minor="${version%.*}"

    log "获取适合 Python ${version} 的 get-pip.py..."
    local get_pip_url
    case "$major_minor" in
        "3.6"|"3.7")
            get_pip_url="${GET_PIP_BASE_URL}/pip/${major_minor}/get-pip.py"
            ;;
        *)
            get_pip_url="${GET_PIP_BASE_URL}/get-pip.py"
            ;;
    esac

    log "从 ${get_pip_url} 下载安装脚本..."
    local temp_file=$(mktemp)
    curl -sSL "$get_pip_url" -o "$temp_file" || error_exit "下载失败: ${get_pip_url}"

    log "使用 get-pip.py 安装 pip..."
    "$pybin" "$temp_file" || error_exit "get-pip.py 安装失败: Python ${version}"
    rm -f "$temp_file"

    log "✅ Python ${version} 成功使用 get-pip.py 安装 pip"
}

verify_pip_installation() {
    local pybin="$1"
    local version="$2"

    log "验证 pip 安装..."
    if ! "$pybin" -m pip --version; then
        error_exit "Python ${version} 的 pip 验证失败"
    fi
}

reinstall_pip_for_python() {
    local version="$1"
    local pybin="${PYTHON_BIN_DIR}/python${version}"

    if ! check_python_binary "$version"; then
        return
    fi

    log "开始处理 Python ${version} (${pybin})..."

    uninstall_existing_pip "$pybin" "$version"

    if ! install_with_ensurepip "$pybin" "$version"; then
        install_with_get_pip "$pybin" "$version"
    fi

    verify_pip_installation "$pybin" "$version"
}

post_install() {
    echo -e "\n${GREEN}✅ 所有 Python 版本的 pip 重新安装完成${NC}"
    echo -e "\n${YELLOW}使用方法示例:${NC}"
    echo -e "  ${PYTHON_BIN_DIR}/pip3.10 install package"
    echo -e "  ${PYTHON_BIN_DIR}/python3.11 -m pip install package"
}

main() {
    log "开始为多版本 Python 重新安装 pip..."

    for version in "${PYTHON_VERSIONS[@]}"; do
        reinstall_pip_for_python "$version"
    done

    post_install
}

main "$@"
