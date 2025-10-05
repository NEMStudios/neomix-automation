#!/bin/bash
set -eo pipefail

# =====================================
# Neovim + LazyVim 备份脚本 (无需sudo权限)
# 版本: 1.1
# 作者: Elijah
# =====================================

# 全局配置
readonly APP_NAME="Neovim + LazyVim Backup"
readonly VERSION="1.1"
readonly DATE_STR="$(date +%Y%m%d_%H%M%S)"
readonly BACKUP_ROOT="${HOME}/Development/3_Data/backups"
readonly BACKUP_DIR="${BACKUP_ROOT}/nvim_migration_backup_${DATE_STR}"
readonly BIN_DIR="${BACKUP_DIR}/bin"
readonly FINAL_ARCHIVE="${BACKUP_ROOT}/nvim_backup_${DATE_STR}.tgz"
readonly NVIM_CONFIG_SYMLINK="${HOME}/Development/0_Config/tool_profiles/nvim"
readonly NVIM_CONFIG_REAL_DIR="${HOME}/Development/0_Config/dotfiles/lazyvim/.config/nvim"
readonly NVIM_DATA_REAL_DIR="${HOME}/Development/0_Config/tool_profiles/lazyvim/.local/share/nvim"
readonly TARGET_CMDS=("fzf" "tree" "yazi" "ya" "dysk" "btm" "dust" "exa" "gping" "rg" "zoxide")

# 颜色定义
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# ======================
# 功能函数定义
# ======================

show_header() {
  echo -e "${GREEN}=====================================${NC}"
  echo -e "${BLUE}BASE MEDIA, PLE - Neovim 备份脚本 v${VERSION}${NC}"
  echo -e "${BLUE}运行: ${APP_NAME}${NC}"
  echo -e "${GREEN}=====================================${NC}"
}

show_help() {
  echo -e "${BLUE}使用:${NC} $(basename "$0") [选项]"
  echo
  echo "选项:"
  echo "  -h, --help     显示帮助信息"
  echo "  -v, --version  显示版本信息"
  echo
  echo "功能: 备份 Neovim 配置、数据和二进制文件到 ${BACKUP_ROOT}"
}

show_version() {
  echo "${APP_NAME} 版本 ${VERSION}"
}

log() {
  echo -e "${GREEN}[$(date +'%T')] $1${NC}"
}

warn() {
  echo -e "${YELLOW}[WARN $(date +'%T')] $1${NC}"
}

error_exit() {
  echo -e "${RED}[ERROR $(date +'%T')] 错误: $1${NC}" >&2
  exit 1
}

check_dependencies() {
  local dependencies=("tar" "gzip" "readlink")
  for cmd in "${dependencies[@]}"; do
    if ! command -v "${cmd}" >/dev/null; then
      error_exit "所需命令 ${cmd} 未安装！"
    fi
  done
}

create_directories() {
  log "创建备份目录结构..."
  mkdir -p "${BIN_DIR}" || error_exit "无法创建目录 ${BIN_DIR}"
}

backup_nvim_config() {
  log "备份 Neovim 配置..."

  # 检查符号链接是否存在
  if [[ -L "${NVIM_CONFIG_SYMLINK}" ]]; then
    local real_path=$(readlink -f "${NVIM_CONFIG_SYMLINK}")
    log "检测到符号链接: ${NVIM_CONFIG_SYMLINK} -> ${real_path}"

    # 备份符号链接本身
    log "备份符号链接本身..."
    if ! tar czf "${BACKUP_DIR}/nvim_symlink.tgz" -C "$(dirname "${NVIM_CONFIG_SYMLINK}")" "$(basename "${NVIM_CONFIG_SYMLINK}")"; then
      error_exit "Neovim 符号链接备份失败"
    fi
  fi

  # 备份实际的配置目录
  if [[ -d "${NVIM_CONFIG_REAL_DIR}" ]]; then
    log "备份实际配置目录: ${NVIM_CONFIG_REAL_DIR}"
    if ! tar czf "${BACKUP_DIR}/nvim_config.tgz" -C "$(dirname "${NVIM_CONFIG_REAL_DIR}")" "$(basename "${NVIM_CONFIG_REAL_DIR}")"; then
      error_exit "Neovim 实际配置备份失败"
    fi
  else
    warn "未找到 Neovim 实际配置目录：${NVIM_CONFIG_REAL_DIR}"
  fi
}

backup_nvim_data() {
  log "备份 Neovim 数据..."

  if [[ -d "${NVIM_DATA_REAL_DIR}" ]]; then
    log "备份实际数据目录: ${NVIM_DATA_REAL_DIR}"
    if ! tar czf "${BACKUP_DIR}/nvim_data.tgz" -C "$(dirname "${NVIM_DATA_REAL_DIR}")" "$(basename "${NVIM_DATA_REAL_DIR}")"; then
      error_exit "Neovim 数据备份失败"
    fi
  else
    warn "未找到 Neovim 数据目录：${NVIM_DATA_REAL_DIR}"
  fi
}

backup_binaries() {
  log "备份 nvim 可执行文件..."
  if command -v nvim >/dev/null; then
    cp "$(command -v nvim)" "${BIN_DIR}/" || error_exit "无法复制 nvim 可执行文件"
  else
    error_exit "未找到 nvim 可执行文件！"
  fi

  for cmd in "${TARGET_CMDS[@]}"; do
    if command -v "${cmd}" >/dev/null; then
      log "备份 ${cmd} 可执行文件..."
      cp "$(command -v "${cmd}")" "${BIN_DIR}/" || warn "无法复制 ${cmd} 可执行文件"
    else
      warn "未找到命令 '${cmd}'，跳过..."
    fi
  done
}

create_final_archive() {
  log "创建最终压缩归档..."
  if tar czf "${FINAL_ARCHIVE}" -C "${BACKUP_ROOT}" "$(basename "${BACKUP_DIR}")"; then
    echo -e "\n${GREEN}✅ 备份成功完成！${NC}"
    echo -e "${YELLOW}归档文件: ${FINAL_ARCHIVE}${NC}"
    # 可选：删除中间目录
    # rm -rf "${BACKUP_DIR}" || warn "无法删除临时目录 ${BACKUP_DIR}"
  else
    error_exit "压缩归档创建失败！"
  fi
}

main() {
  # 参数处理
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        show_help
        exit 0
        ;;
      -v|--version)
        show_version
        exit 0
        ;;
      *)
        error_exit "未知参数: $1"
        ;;
    esac
    shift
  done

  show_header
  check_dependencies
  create_directories
  backup_nvim_config
  backup_nvim_data
  backup_binaries
  create_final_archive
}

main "$@"
