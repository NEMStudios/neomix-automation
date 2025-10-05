#!/bin/bash
set -eo pipefail

APP_NAME="Programming Environment Setup"
ROCKY_VERSION="9"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}====================================="
echo -e "\033[1;32mBASE MEDIA, PLE - Rocky Linux ${ROCKY_VERSION}.* Install Script"
echo -e "\033[1;32mSetting $APP_NAME"
echo -e "${GREEN}=====================================${NC}"

# Global variables
USER_HOME="$(getent passwd ${SUDO_USER:-$(whoami)} | cut -d: -f6)"
DEV_ROOT="${USER_HOME}/Development"
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

setup_git_config() {
    log "配置 Git 全局设置..."
    git config --global user.name "Илья"
    git config --global user.email "elijah.nemstudios@foxmail.com"

    log "生成 SSH 密钥..."
    if [ ! -f "${USER_HOME}/.ssh/id_rsa" ]; then
        ssh-keygen -t rsa -b 4096 -C "elijah.nemstudios@foxmail.com" -f "${USER_HOME}/.ssh/id_rsa" -N ""
    else
        warn "SSH 密钥已存在，跳过生成"
    fi

    log "迁移 Git 配置到开发目录..."
    mkdir -p "${DEV_ROOT}/0_Config/dotfiles/git"
    if [ -f "${USER_HOME}/.gitconfig" ]; then
        mv "${USER_HOME}/.gitconfig" "${DEV_ROOT}/0_Config/dotfiles/git/"
    fi
    ln -sf "${DEV_ROOT}/0_Config/dotfiles/git/.gitconfig" "${USER_HOME}/.gitconfig"
}

install_python_tools() {
    log "安装 Python 和 pip..."
    run_dnf install -y python3 python3-pip python3-devel

    log "配置 pip 阿里云镜像源..."
    mkdir -p "${USER_HOME}/.pip"
    cat > "${USER_HOME}/.pip/pip.conf" <<-'EOF'
[global]
index-url = https://mirrors.aliyun.com/pypi/simple/
trusted-host = mirrors.aliyun.com
EOF

    log "验证 Python 环境:"
    python3 --version
    pip3 --version
}

install_neovim() {
    local nvim_version="v0.11.2"
    local nvim_dir="/opt/nvim"

    log "安装 NeoVim ${nvim_version}..."
    if command -v nvim &>/dev/null; then
        warn "NeoVim 已安装，跳过"
        return
    fi

    local temp_dir=$(mktemp -d)
    cd "${temp_dir}"

    log "下载 NeoVim 二进制包..."
    curl -LO "https://github.com/neovim/neovim/releases/download/${nvim_version}/nvim-linux-x86_64.tar.gz" || \
        error_exit "Failed to download NeoVim"

    log "安装 NeoVim..."
    tar xzf nvim-linux-x86_64.tar.gz || error_exit "Failed to extract NeoVim"
    sudo mv nvim-linux-x86_64 "${nvim_dir}" || error_exit "Failed to move NeoVim"
    sudo ln -sf "${nvim_dir}/bin/nvim" "/usr/local/bin/nvim" || error_exit "Failed to create symlink"

    log "验证安装:"
    nvim --version || error_exit "NeoVim 安装失败"

    cd ~
    rm -rf "${temp_dir}"
}

setup_lazyvim() {
    log "配置 LazyVim..."
    local lazyvim_dir="${DEV_ROOT}/0_Config/dotfiles/lazyvim/.config/nvim"

    if [ -d "${lazyvim_dir}" ]; then
        warn "LazyVim 配置已存在，跳过"
        return
    fi

    log "克隆 LazyVim 模板..."
    git clone --depth=1 https://github.com/LazyVim/starter "${lazyvim_dir}" || \
        error_exit "Failed to clone LazyVim"
    rm -rf "${lazyvim_dir}/.git"

    log "创建配置链接..."
    mkdir -p "${USER_HOME}/.config"
    ln -sf "${lazyvim_dir}" "${USER_HOME}/.config/nvim" || \
        warn "Failed to create nvim config symlink"
}

install_nodejs() {
    log "安装 Node.js..."
    if command -v node &>/dev/null; then
        warn "Node.js 已安装，跳过"
        return
    fi

    curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash - || \
        error_exit "Failed to setup NodeSource repo"

    run_dnf install -y nodejs

    log "验证 Node.js 安装:"
    node --version
    npm --version
}

install_lazygit() {
    log "安装 LazyGit..."
    if command -v lazygit &>/dev/null; then
        warn "LazyGit 已安装，跳过"
        return
    fi

    sudo dnf copr enable atim/lazygit -y || \
        warn "Failed to enable copr repo - trying direct install"

    run_dnf install -y lazygit

    log "验证安装:"
    lazygit --version || error_exit "LazyGit 安装失败"
}

configure_ssh_service() {
    log "配置 SSH 服务..."
    sudo systemctl enable --now sshd || \
        warn "Failed to enable sshd service"

    log "配置防火墙..."
    sudo firewall-cmd --permanent --add-service=ssh || \
        warn "Failed to add ssh service to firewall"
    sudo firewall-cmd --reload || \
        warn "Failed to reload firewall"

    log "SSH 服务状态:"
    sudo systemctl status sshd --no-pager
}

post_install() {
    echo -e "\n${GREEN}✅ $APP_NAME 配置完成${NC}"
    echo -e "\n${YELLOW}后续建议操作:${NC}"
    echo -e "1. 将 SSH 公钥添加到 GitHub/GitLab:"
    echo -e "   cat ~/.ssh/id_rsa.pub"
    echo -e "2. 运行 nvim 完成插件安装"
    echo -e "3. 检查 LazyGit 配置"

    read -rp "是否现在重启系统？[y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}将在10秒后重启...${NC}"
        sleep 10
        sudo reboot
    fi
}

main() {
    check_sudo
    setup_git_config
    install_python_tools
    install_neovim
    setup_lazyvim
    install_nodejs
    install_lazygit
    configure_ssh_service
    post_install
}

main "$@"
