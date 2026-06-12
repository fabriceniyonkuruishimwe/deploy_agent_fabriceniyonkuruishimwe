#!/usr/bin/env bash
# =============================================================================
#  setup_project.sh — Automated Project Bootstrapper
#  Student Attendance Tracker — Project Factory
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; }

print_banner() {
  echo -e "${BOLD}${CYAN}"
  echo "=========================================="
  echo "  Student Attendance Tracker Project Setup"
  echo "=========================================="
  echo -e "${RESET}"
}

SCRIPT_DIR="$(pwd)"
PROJECT_NAME=""
PROJECT_DIR=""

cleanup_on_interrupt() {
  echo ""
  warn "Interrupt received (Ctrl+C). Running cleanup..."
  if [[ -n "$PROJECT_DIR" && -d "$PROJECT_DIR" ]]; then
    ARCHIVE_NAME="${PROJECT_NAME}_archive"
    info "Archiving current state to ${ARCHIVE_NAME}.tar.gz"
    tar -czf "${SCRIPT_DIR}/${ARCHIVE_NAME}.tar.gz" -C "${SCRIPT_DIR}" "$(basename "$PROJECT_DIR")" 2>/dev/null || true
    info "Removing incomplete project directory..."
    rm -rf "$PROJECT_DIR"
    success "Archive saved: ${SCRIPT_DIR}/${ARCHIVE_NAME}.tar.gz"
  else
    warn "No project directory found to archive."
  fi
  echo -e "${RED}Setup aborted.${RESET}"
  exit 1
}

trap cleanup_on_interrupt SIGINT SIGTERM

get_project_name() {
  echo ""
  echo -e "${BOLD}Step 1 of 4 - Project Name${RESET}"
  echo "------------------------------------"
  while true; do
    read -rp "Enter a project identifier (letters/numbers/underscores): " user_input
    user_input="${user_input//[[:space:]]/_}"
    if [[ -z "$user_input" ]]; then
      warn "Identifier cannot be empty. Please try again."
    elif [[ ! "$user_input" =~ ^[a-zA-Z0-9_]+$ ]]; then
      warn "Only letters, numbers, and underscores are allowed."
    else
      PROJECT_NAME="attendance_tracker_${user_input}"
      PROJECT_DIR="${SCRIPT_DIR}/${PROJECT_NAME}"
      success "Project directory will be: ${PROJECT_DIR}"
      break
    fi
  done
}

create_directory_structure() {
  echo ""
  echo -e "${BOLD}Step 2 of 4 - Building Directory Structure${RESET}"
  echo "------------------------------------"
  if [[ -d "$PROJECT_DIR" ]]; then
    warn "Directory '${PROJECT_NAME}' already exists."
    read -rp "Overwrite it? [y/N]: " overwrite
    if [[ "${overwrite,,}" != "y" ]]; then
      error "Setup cancelled by user."
      exit 0
    fi
    rm -rf "$PROJECT_DIR"
  fi

  mkdir -p "${PROJECT_DIR}/Helpers"
  mkdir -p "${PROJECT_DIR}/reports"
  success "Created: ${PROJECT_NAME}/"
  success "Created: ${PROJECT_NAME}/Helpers/"
  success "Created: ${PROJECT_NAME}/reports/"

  if [[ -f "${SCRIPT_DIR}/attendance_checker.py" ]]; then
    cp "${SCRIPT_DIR}/attendance_checker.py" "${PROJECT_DIR}/attendance_checker.py"
    success "Copied: attendance_checker.py"
  else
    error "Source file not found: attendance_checker.py"
    exit 1
  fi

  if [[ -f "${SCRIPT_DIR}/assets.csv" ]]; then
    cp "${SCRIPT_DIR}/assets.csv" "${PROJECT_DIR}/Helpers/assets.csv"
    success "Copied: Helpers/assets.csv"
  else
    error "Source file not found: assets.csv"
    exit 1
  fi

  if [[ -f "${SCRIPT_DIR}/config.json" ]]; then
    cp "${SCRIPT_DIR}/config.json" "${PROJECT_DIR}/Helpers/config.json"
    success "Copied: Helpers/config.json"
  else
    error "Source file not found: config.json"
    exit 1
  fi

  echo "# Attendance Reports Log" > "${PROJECT_DIR}/reports/reports.log"
  success "Created: reports/reports.log"
}

configure_thresholds() {
  echo ""
  echo -e "${BOLD}Step 3 of 4 - Attendance Threshold Configuration${RESET}"
  echo "------------------------------------"
  local config_file="${PROJECT_DIR}/Helpers/config.json"
  info "Current thresholds in config.json:"
  grep -E '"warning"|"failure"' "$config_file"

  echo ""
  read -rp "Do you want to update the attendance thresholds? [y/N]: " update_choice
  if [[ "${update_choice,,}" != "y" ]]; then
    info "Keeping default thresholds."
    return
  fi

  while true; do
    read -rp "Enter new WARNING threshold % (default 75): " new_warning
    new_warning="${new_warning:-75}"
    if [[ ! "$new_warning" =~ ^[0-9]+$ ]] || (( new_warning < 1 || new_warning > 100 )); then
      warn "Please enter a whole number between 1 and 100."
    else
      break
    fi
  done

  while true; do
    read -rp "Enter new FAILURE threshold % (default 50): " new_failure
    new_failure="${new_failure:-50}"
    if [[ ! "$new_failure" =~ ^[0-9]+$ ]] || (( new_failure < 1 || new_failure > 100 )); then
      warn "Please enter a whole number between 1 and 100."
    elif (( new_failure >= new_warning )); then
      warn "Failure threshold must be less than warning threshold."
    else
      break
    fi
  done

  sed -i "s/\"warning\": [0-9]*/\"warning\": ${new_warning}/" "$config_file"
  sed -i "s/\"failure\": [0-9]*/\"failure\": ${new_failure}/" "$config_file"
  success "config.json updated!"
  grep -E '"warning"|"failure"' "$config_file"
}

run_health_check() {
  echo ""
  echo -e "${BOLD}Step 4 of 4 - Environment Health Check${RESET}"
  echo "------------------------------------"
  echo -n "  Checking python3 installation... "
  if command -v python3 &>/dev/null; then
    PY_VERSION=$(python3 --version 2>&1)
    echo -e "${GREEN}FOUND${RESET} (${PY_VERSION})"
  else
    echo -e "${RED}NOT FOUND${RESET}"
    warn "python3 is not installed."
  fi

  echo ""
  info "Verifying project directory structure..."
  local all_ok=true
  local expected_items=(
    "${PROJECT_DIR}/attendance_checker.py"
    "${PROJECT_DIR}/Helpers"
    "${PROJECT_DIR}/Helpers/assets.csv"
    "${PROJECT_DIR}/Helpers/config.json"
    "${PROJECT_DIR}/reports"
    "${PROJECT_DIR}/reports/reports.log"
  )

  for item in "${expected_items[@]}"; do
    rel_path="${item#${SCRIPT_DIR}/}"
    if [[ -e "$item" ]]; then
      echo -e "  ${GREEN}OK${RESET}  ${rel_path}"
    else
      echo -e "  ${RED}MISSING${RESET}  ${rel_path}"
      all_ok=false
    fi
  done

  echo ""
  if $all_ok; then
    success "All required files and directories are present."
  else
    error "Some files are missing. Please re-run the script."
    exit 1
  fi
}

print_summary() {
  echo ""
  echo -e "${BOLD}${GREEN}"
  echo "=========================================="
  echo "           Setup Complete!"
  echo "=========================================="
  echo -e "${RESET}"
  echo -e "  ${BOLD}Project directory:${RESET} ${PROJECT_DIR}"
  echo ""
  echo -e "  ${BOLD}To run the tracker:${RESET}"
  echo -e "    cd ${PROJECT_NAME}"
  echo -e "    python3 attendance_checker.py"
  echo ""
  echo -e "  ${BOLD}To trigger archive feature:${RESET}"
  echo -e "    Press Ctrl+C while the script is running."
  echo ""
}

main() {
  print_banner
  get_project_name
  create_directory_structure
  configure_thresholds
  run_health_check
  print_summary
}

main
