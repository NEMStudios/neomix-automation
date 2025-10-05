#!/bin/bash
set -eo pipefail

APP_NAME="Zsh & Oh My Zsh"
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
OHMYZSH_ROOT="${DEV_ROOT}/0_Config/tool_profiles/oh-my-zsh"

# Path configurations
BASHRC="${DEV_ROOT}/0_Config/dotfiles/bash/.bashrc"
ZSHRC="${DEV_ROOT}/0_Config/dotfiles/zsh/.zshrc"
STARSHIP_CONFIG="${DEV_ROOT}/0_Config/dotfiles/starship"
ZSH_CUSTOM="${OHMYZSH_ROOT}/.oh-my-zsh/custom"

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

install_zsh() {
    log "安装 zsh 及必要组件..."
    run_dnf install -y which util-linux-user zsh git

    log "设置用户默认 shell 为 zsh..."
    if ! chsh -s "$(which zsh)"; then
        warn "Failed to change default shell to zsh"
    fi
}

setup_ohmyzsh() {
    log "配置 Oh My Zsh 目录结构..."
    mkdir -p "${OHMYZSH_ROOT}/.oh-my-zsh" || error_exit "Failed to create Oh My Zsh directory"

    log "安装 Oh My Zsh..."
    if [ ! -d "${OHMYZSH_ROOT}/.oh-my-zsh/.git" ]; then
        git clone --depth=1 https://gitee.com/mirrors/oh-my-zsh.git "${OHMYZSH_ROOT}/.oh-my-zsh" || \
        error_exit "Failed to clone Oh My Zsh"
    fi

    log "初始化 zsh 配置文件..."
    if [ ! -f "${ZSHRC}" ]; then
        # 先创建基础配置文件
        cp "${OHMYZSH_ROOT}/.oh-my-zsh/templates/zshrc.zsh-template" "${ZSHRC}" || \
        warn "Failed to copy zshrc template"

        # 立即备份原始文件
        cp "${ZSHRC}" "${ZSHRC}.bak"
    fi

    log "创建软链接..."
    ln -sf "${OHMYZSH_ROOT}/.oh-my-zsh" "${USER_HOME}/.oh-my-zsh" || warn "Failed to create Oh My Zsh symlink"
    ln -sf "${ZSHRC}" "${USER_HOME}/.zshrc" || warn "Failed to create .zshrc symlink"
}

install_zsh_plugins() {
    log "安装 zsh 插件..."

    declare -A plugins=(
        ["zsh-autosuggestions"]="https://gitee.com/phpxxo/zsh-autosuggestions.git"
        ["zsh-syntax-highlighting"]="https://gitee.com/mirrors/zsh-syntax-highlighting.git"
    )

    for plugin in "${!plugins[@]}"; do
        if [ ! -d "${ZSH_CUSTOM}/plugins/${plugin}" ]; then
            git clone --depth=1 "${plugins[$plugin]}" "${ZSH_CUSTOM}/plugins/${plugin}" || \
            warn "Failed to install ${plugin} plugin"
        fi
    done

    log "配置插件..."
    # 使用更安全的 sed 修改方式
    sed -i '/^plugins=/c\plugins=(git sudo z zsh-autosuggestions zsh-syntax-highlighting)' "${ZSHRC}"
}

setup_shell_history() {
    log "配置 shell 历史记录..."
    mkdir -p "${DEV_ROOT}/0_Config/shell_history"

    touch "${DEV_ROOT}/0_Config/shell_history/.zsh_history" || warn "Failed to create zsh history file"
    ln -sf "${DEV_ROOT}/0_Config/shell_history/.zsh_history" "${USER_HOME}/.zsh_history" || \
    warn "Failed to create zsh history symlink"

    if [ -f "${USER_HOME}/.bash_history" ]; then
        mv "${USER_HOME}/.bash_history" "${DEV_ROOT}/0_Config/shell_history/" || \
        warn "Failed to move bash history"
        ln -sf "${DEV_ROOT}/0_Config/shell_history/.bash_history" "${USER_HOME}/.bash_history" || \
        warn "Failed to create bash history symlink"
    fi

    if [ -f "${USER_HOME}/.bashrc" ]; then
        mv "${USER_HOME}/.bashrc" "${DEV_ROOT}/0_Config/dotfiles/bash/" || \
        warn "Failed to move .bashrc"
        ln -sf "${DEV_ROOT}/0_Config/dotfiles/bash/.bashrc" "${USER_HOME}/.bashrc" || \
        warn "Failed to create .bashrc symlink"
    fi
}

setup_custom_aliases() {
    log "添加自定义 aliases..."

    # 先检查是否已经添加过
    if ! grep -q "Custom Python virtualenv aliases" "${ZSHRC}"; then
        cat >> "${ZSHRC}" <<-'EOF'

# Custom aliases: easypython - Python virtualenv
alias easypython-venv37="source ~/.venvs/venv37/bin/activate"
alias easypython-venv39="source ~/.venvs/venv39/bin/activate"
alias easypython-venv310="source ~/.venvs/venv310/bin/activate"
alias easypython-venv311="source ~/.venvs/venv311/bin/activate"
alias easypython-venv314="source ~/.venvs/venv314/bin/activate"

# Custom aliases: easyconda - Conda environments
alias easyconda-activate="source /opt/miniconda3/bin/activate"

# Custom aliases: v2rayN
proxy_on() {
    export ALL_PROXY="socks5://127.0.0.1:10808"
    export HTTP_PROXY="socks5://127.0.0.1:10808"
    export HTTPS_PROXY="socks5://127.0.0.1:10808"
    echo "Proxy ON: $ALL_PROXY"
}

proxy_off() {
    unset ALL_PROXY HTTP_PROXY HTTPS_PROXY
    echo "Proxy OFF"
}

# Custom aliases: Utilities
alias cls="clear"
alias spt="speedtest-cli"
EOF
    fi
}

install_starship() {
    log "安装 Starship 提示符..."

    if ! command -v starship &>/dev/null; then
        curl -sS https://starship.rs/install.sh | sh || error_exit "Failed to install Starship"
    fi

    log "配置 Starship..."
    mkdir -p "${STARSHIP_CONFIG}"

    if [ ! -f "${STARSHIP_CONFIG}/starship.toml" ]; then
        wget -q -O "${STARSHIP_CONFIG}/starship.toml" \
        https://starship.rs/presets/toml/plain-text-symbols.toml || \
        warn "Failed to download Starship config"
    fi

    ln -sf "${STARSHIP_CONFIG}/starship.toml" "${USER_HOME}/.config/starship.toml" || \
    warn "Failed to create Starship config symlink"

    # 确保 starship 配置添加在文件末尾
    if ! grep -q "starship init zsh" "${ZSHRC}"; then
        cat >> "${ZSHRC}" <<-'EOF'

# Starship
eval "$(starship init zsh)"
EOF
    fi

    # 确保 starship 配置添加在文件末尾
    if ! grep -q "starship init bash" "${BASHRC}"; then
        cat >> "${BASHRC}" <<-'EOF'

# Starship
eval "$(starship init bash)"
EOF
    fi
}

post_install() {
    echo -e "\n${GREEN}✅ $APP_NAME 安装与配置完成！${NC}"
    echo -e "\n${YELLOW}请重新登录或重启终端以应用 zsh 配置${NC}"
}

main() {
    check_sudo
    install_zsh
    setup_ohmyzsh
    install_zsh_plugins
    setup_shell_history
    setup_custom_aliases
    install_starship
    post_install
}

main "$@"
