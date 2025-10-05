#!/bin/bash
set -eo pipefail

APP_NAME="Multiple Python Versions & Miniconda"
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
DEV_ROOT="${USER_HOME}/Development"
INSTALL_ROOT="/opt/python"
MINICONDA_DIR="/opt/miniconda3"
PYTHON_VERSIONS=(
    "3.7.9"
    "3.9.10"
    "3.10.10"
    "3.11.7"
)

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

install_build_dependencies() {
    log "安装编译依赖..."
    local build_packages=(
        "Development Tools"
        gcc openssl-devel bzip2-devel
        libffi-devel zlib-devel xz-devel
        wget make tar readline-devel
        sqlite-devel
    )

    run_dnf groupinstall -y "${build_packages[0]}"
    run_dnf install -y "${build_packages[@]:1}"
}

# 1. 源码编译安装
compile_python_version() {
    local version="$1"
    local major_minor="${version%.*}"
    local install_path="${INSTALL_ROOT}/${version}"
    local source_url="https://mirrors.aliyun.com/python-release/source/Python-${version}.tgz"

    log "开始安装 Python ${version}..."

    # Create temp directory
    local temp_dir=$(mktemp -d)
    cd "${temp_dir}" || error_exit "无法进入临时目录"

    log "下载源码包..."
    sudo wget -q "${source_url}" -O "Python-${version}.tgz" || \
        error_exit "下载失败: ${source_url}"

    log "解压并编译..."
    sudo tar -xzf "Python-${version}.tgz" || error_exit "解压失败"
    cd "Python-${version}" || error_exit "无法进入源码目录"

    sudo ./configure \
        --enable-optimizations \
        --without-ensurepip \
        --prefix="${install_path}" || \
        error_exit "配置失败"

    sudo PROFILE_TASK='true' make -j"$(nproc)" || \
        error_exit "编译失败"

    sudo make altinstall || \
        error_exit "安装失败"

    log "创建版本化链接..."
    sudo mkdir -p "${INSTALL_ROOT}/bin"
    sudo ln -sf "${install_path}/bin/python${major_minor}" \
        "${INSTALL_ROOT}/bin/python${major_minor}"
    sudo ln -sf "${install_path}/bin/pip${major_minor}" \
        "${INSTALL_ROOT}/bin/pip${major_minor}"

    # Cleanup
    cd ~
    sudo rm -rf "${temp_dir}"
}

install_all_python_versions() {
    for version in "${PYTHON_VERSIONS[@]}"; do
        if [ -f "${INSTALL_ROOT}/bin/python${version%.*}" ]; then
            warn "Python ${version} 已安装，跳过"
            continue
        fi
        compile_python_version "${version}"
    done
}

# 2. Miniconda安装和管理
install_miniconda() {
    log "安装 Miniconda..."
    local miniconda_installer="/tmp/miniconda_installer.sh"

    if [ -d "${MINICONDA_DIR}" ]; then
        warn "Miniconda 已安装，跳过"
        return
    fi

    log "下载安装包..."
    sudo wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
        -O "${miniconda_installer}" || \
        error_exit "下载 Miniconda 失败"

    log "执行安装..."
    sudo bash "${miniconda_installer}" -b -p "${MINICONDA_DIR}" || \
        error_exit "Miniconda 安装失败"
    sudo rm -f "${miniconda_installer}"

    log "配置 conda 环境..."
    local conda_envs_path="${DEV_ROOT}/0_Config/conda_envs"
    local conda_pkgs_path="${DEV_ROOT}/9_Temporary/conda_pkgs"

    sudo chown -R "${SUDO_USER}:${SUDO_USER}" "${conda_envs_path}" "${conda_pkgs_path}"

    log "设置 condarc 配置..."
    mkdir -p "${DEV_ROOT}/0_Config/dotfiles/conda"
    cat > "${DEV_ROOT}/0_Config/dotfiles/conda/.condarc" <<-EOF
envs_dirs:
  - ${conda_envs_path}
pkgs_dirs:
  - ${conda_pkgs_path}
EOF

    ln -sf "${DEV_ROOT}/0_Config/dotfiles/conda/.condarc" "${USER_HOME}/.condarc"
}

# 3. UV安装和管理
install_uv_astral() {
    log "安装 UV (Astral.sh 的 Python 包管理器)..."

    if command -v uv &>/dev/null; then
        warn "UV 已安装，跳过"
        return
    fi

    log "下载并安装 UV..."
    curl -LsSf https://astral.sh/uv/install.sh | sh || \
        error_exit "UV 安装失败"

    log "验证 UV 安装..."
    if ! uv --version; then
        error_exit "UV 安装验证失败"
    fi

    log "当前已安装的 Python 版本:"
    uv python list || \
        warn "无法列出已安装的 Python 版本"
}

setup_environment() {
    log "环境配置说明:"
    echo -e "\n${GREEN}✅ Python 多版本安装完成${NC}"
    echo -e "\n${YELLOW}使用方法:${NC}"
    echo -e "1. 使用特定 Python 版本:"
    echo -e "   ${INSTALL_ROOT}/bin/pythonX.Y"
    echo -e "2. 将以下内容添加到 ~/.bashrc 或 ~/.zshrc 来启用:"
    echo -e "   export PATH=\"${INSTALL_ROOT}/bin:\$PATH\""
    echo -e "3. Miniconda 使用前需初始化:"
    echo -e "   source ${MINICONDA_DIR}/bin/activate"
    echo -e "4. Conda 环境存储在:"
    echo -e "   ${DEV_ROOT}/0_Config/conda_envs"
    echo -e "5. 版本优先级:"
    echo -e "   源码编译 > Miniconda > UV"
    echo -e "   查看所有版本: ${INSTALL_ROOT}/bin/pythonX.Y 或 uv python list"
}

main() {
    check_sudo
    install_build_dependencies

    # 按优先级安装
    install_all_python_versions      # 第一选择
    install_miniconda                # 第二选择
    install_uv_astral                # 第三选择

    setup_environment
}

main "$@"
