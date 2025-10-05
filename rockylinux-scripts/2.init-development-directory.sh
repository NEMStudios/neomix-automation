#!/bin/bash
set -eo pipefail

APP_NAME="Development Directory Initializer"
ROCKY_VERSION="9"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}====================================="
echo -e "\033[1;32mBASE MEDIA, PLE - Rocky Linux ${ROCKY_VERSION}.* Install Script"
echo -e "\033[1;32mSetting $APP_NAME"
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

USER_HOME="$(getent passwd ${SUDO_USER:-$(whoami)} | cut -d: -f6)"
DEV_ROOT="${USER_HOME}/Development"
PLATFORMS=("github" "coding")

change_static_hostname() {
    log "更改静态hostname信息..."
    if ! hostnamectl set-hostname nemstudios; then
        error_exit "Failed to set hostname"
    fi
    hostnamectl
}

install_required_packages() {
    local required_packages="xdg-user-dirs ncurses tree git-core"

    log "安装必要软件包..."
    run_dnf install $required_packages -y || {
        error_exit "Failed to install required packages"
    }

    # Check if standard directories exist before updating
    local standard_dirs=("Desktop" "Documents" "Downloads" "Music" "Pictures" "Public" "Templates" "Videos")
    local need_update=false

    for dir in "${standard_dirs[@]}"; do
        if [ ! -d "${USER_HOME}/${dir}" ]; then
            need_update=true
            break
        fi
    done

    if $need_update; then
        log "检测到缺少标准目录，正在更新..."
        if command -v xdg-user-dirs-update &>/dev/null; then
            if ! xdg-user-dirs-update; then
                warn "更新用户目录失败 (非致命错误)"
            fi
        else
            warn "xdg-user-dirs-update 命令未找到 - 跳过更新"
        fi
    else
        log "所有标准目录已存在，无需更新"
    fi
}


create_dev_structure() {
    log "创建开发目录结构..."

    # 定义基础目录和对应的子目录
    declare -A dir_structure=(
        ["${DEV_ROOT}/0_Config/dotfiles"]="bash zsh git stow lazygit lazyvim conda python starship"
        ["${DEV_ROOT}/0_Config/ide_settings"]="PyCharm CLion RustRover"
        ["${DEV_ROOT}/0_Config/tool_profiles"]="oh-my-zsh lazyvim uv starship"
        ["${DEV_ROOT}/0_Config"]="shell_history virtual_envs conda_envs"

        ["${DEV_ROOT}/1_Code/platforms"]="github coding"
        ["${DEV_ROOT}/1_Code/projects"]="active archived sandbox"

        ["${DEV_ROOT}/2_Learning/programming"]="python_notes leetcode"
        ["${DEV_ROOT}/2_Learning"]="certifications"

        ["${DEV_ROOT}/3_Data/datasets"]="raw processed"
        ["${DEV_ROOT}/3_Data"]="knowledge_base backups"

        ["${DEV_ROOT}/4_Operations/deployments"]="ansible k8s"
        ["${DEV_ROOT}/4_Operations"]="tickets monitoring pipelines"

        ["${DEV_ROOT}/5_DCC"]="houdiniProjects"
        ["${DEV_ROOT}/6_Applications"]="fonts icons"

        ["${DEV_ROOT}/9_Temporary"]="scratchpad downloads cache conda_pkgs hfstemplates"
        ["${DEV_ROOT}/9_Temporary/hfstemplates"]="houdini_backup houdini_temp "
    )

    # 创建目录结构
    for base_dir in "${!dir_structure[@]}"; do
        mkdir -p "$base_dir" || warn "Failed to create base directory: $base_dir"

        IFS=' ' read -ra subdirs <<< "${dir_structure[$base_dir]}"
        for subdir in "${subdirs[@]}"; do
            mkdir -p "${base_dir}/${subdir}" || warn "Failed to create subdirectory: ${base_dir}/${subdir}"
        done
    done
}


create_templates() {
    log "创建模板文件..."
    for category in 0_Config 1_Code 2_Learning 3_Data 4_Operations; do
        mkdir -p "${DEV_ROOT}/${category}/_TEMPLATE" || warn "Failed to create template dir for ${category}"
        cat > "${DEV_ROOT}/${category}/_TEMPLATE/README.md.tpl" <<EOF || warn "Failed to create template file for ${category}"
# ${category} Template
EOF
    done
}

set_permissions() {
    log "设置权限..."
    chmod 700 "${DEV_ROOT}/0_Config/dotfiles" || warn "Failed to set permissions for dotfiles"
    find "${DEV_ROOT}/9_Temporary" -type d -exec chmod 777 {} \; || warn "Failed to set temp dir permissions"
    find "${DEV_ROOT}/1_Code" -type d -exec chmod 755 {} \; || warn "Failed to set code dir permissions"
}

create_shortcuts() {
    log "创建快捷方式..."
    for platform in "${PLATFORMS[@]}"; do
        ln -sf "${DEV_ROOT}/1_Code/platforms/${platform}" "${USER_HOME}/dev_${platform}" || warn "Failed to create shortcut for ${platform}"
    done

    declare -A symlinks=(
        ["${DEV_ROOT}/0_Config/virtual_envs"]="${USER_HOME}/.venvs"
        ["${DEV_ROOT}/0_Config/conda_envs"]="${USER_HOME}/.cenvs"
        ["${DEV_ROOT}/0_Config/dotfiles"]="${USER_HOME}/Dotfiles"
        ["${DEV_ROOT}/0_Config/tool_profiles"]="${USER_HOME}/Tool_Profiles"
        ["${DEV_ROOT}/1_Code/projects"]="${USER_HOME}/Projects"
        ["${DEV_ROOT}/2_Learning/programming"]="${USER_HOME}/Programming"
        ["${DEV_ROOT}/3_Data/datasets"]="${USER_HOME}/Datasets"
        ["${DEV_ROOT}/3_Data/knowledge_base"]="${USER_HOME}/Knowledge_Base"
        ["${DEV_ROOT}/4_Operations/tickets"]="${USER_HOME}/Tickets"
        ["${DEV_ROOT}/5_DCC/houdiniProjects"]="${USER_HOME}/Projs_Houdini"
    )

    for target in "${!symlinks[@]}"; do
        ln -sf "$target" "${symlinks[$target]}" || warn "Failed to create shortcut: $target"
    done
}

show_instructions() {
    echo -e "\n${GREEN}✅ 目录结构创建完成，后续建议：${NC}"
    echo -e "1. 配置 dotfiles: cd ${DEV_ROOT}/0_Config/dotfiles && stow -v -t ~ -S */"
    echo -e "2. 创建虚拟环境: python -m venv ${DEV_ROOT}/0_Config/virtual_envs/<env_name>"
    echo -e "3. 添加 alias: alias dev='cd ${DEV_ROOT}'"
    echo -e "4. 清理临时文件: find ${DEV_ROOT}/9_Temporary -mtime +7 -exec rm -rf {} \\;"
}

show_directory_structure() {
    log "展示最终目录结构："
    if command -v tree &> /dev/null; then
        tree -d -L 3 "${DEV_ROOT}" || warn "Failed to show directory tree"
    else
        warn "提示: 安装 tree 命令可视化结构更清晰"
        ls -R "${DEV_ROOT}" | grep ":$" | sed -e 's/:$//' -e 's/[^-][^\/]*\//--/g' || warn "Failed to list directory structure"
    fi
}

init_development_directory() {
    if [ -d "${DEV_ROOT}" ]; then
        echo -e "${YELLOW}警告: 目录 ${DEV_ROOT} 已存在，是否覆盖？[y/N]${NC}"
        read -r answer
        [[ ! "$answer" =~ ^[Yy]$ ]] && error_exit "操作取消"
        rm -rf "${DEV_ROOT}" || error_exit "Failed to remove existing directory"
    fi

    change_static_hostname
    install_required_packages
    create_dev_structure
    create_templates
    set_permissions
    create_shortcuts

    log "初始化完成于 $(date)"
    show_directory_structure
    show_instructions
}

main() {
    check_sudo
    echo -e "${GREEN}开始初始化开发目录...${NC}"
    init_development_directory
}

main "$@"
