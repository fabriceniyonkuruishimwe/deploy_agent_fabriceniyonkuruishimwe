#!/usr/bin/env bash
# =============================================================================
#  setup_project.sh — Automated Project Bootstrapper
#  Student Attendance Tracker — Project Factory
# =============================================================================

set -euo pipefail

# ── Colour helpers ─────────────────────────────────────────────────────────
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

# ── Banner ──────────────────────────────────────────────────────────────────
print_banner() {
  echo -e "${BOLD}${CYAN}"
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║       Student Attendance Tracker — Project Setup     ║"
  echo "║                  setup_project.sh                    ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECT_NAME=""
PROJECT_DIR=""

# =============================================================================
# SECTION 1 — SIGNAL TRAP (SIGINT / Ctrl+C)
# =============================================================================
cleanup_on_interrupt() {
  echo ""
  warn "Interrupt received (Ctrl+C). Running cleanup…"

  if [[ -n "$PROJECT_DIR" && -d "$PROJECT_DIR" ]]; then
    ARCHIVE_NAME="${PROJECT_NAME}_archive"

    info "Archiving current state → ${ARCHIVE_NAME}.tar.gz"
    tar -czf "${SCRIPT_DIR}/${ARCHIVE_NAME}.tar.gz" \
        -C "${SCRIPT_DIR}" \
        "$(basename "$PROJECT_DIR")" 2>/dev/null || true

    info "Removing incomplete project directory: $PROJECT_DIR"
    rm -rf "$PROJECT_DIR"

    success "Archive saved: ${SCRIPT_DIR}/${ARCHIVE_NAME}.tar.gz"
  else
    warn "No project directory found to archive."
  fi

  echo -e "${RED}Setup aborted.${RESET}"
  exit 1
}

trap cleanup_on_interrupt SIGINT SIGTERM

# =============================================================================
# SECTION 2 — USER INPUT: Project Name
# =============================================================================
get_project_name() {
  echo ""
  echo -e "${BOLD}Step 1 of 4 — Project Name${RESET}"
  echo "────────────────────────────────────────"

  while true; do
    read -rp "$(echo -e ${YELLOW}"Enter a project identifier (letters/numbers/underscores): "${RESET})" user_input

    user_input="${user_input//[[:space:]]/_}"

    if [[ -z "$user_input" ]]; then
      warn "Identifier cannot be empty. Please try again."
    elif [[ ! "$user_input" =~ ^[a-zA-Z0-9_]+$ ]]; then
      warn "Only letters, numbers, and underscores are allowed. Please try again."
    else
      PROJECT_NAME="attendance_tracker_${user_input}"
      PROJECT_DIR="${SCRIPT_DIR}/${PROJECT_NAME}"
      success "Project directory will be: ${PROJECT_DIR}"
      break
    fi
  done
}

# =============================================================================
# SECTION 3 — DIRECTORY ARCHITECTURE
# =============================================================================
create_directory_structure() {
  echo ""
  echo -e "${BOLD}Step 2 of 4 — Building Directory Structure${RESET}"
  echo "────────────────────────────────────────"

  if [[ -d "$PROJECT_DIR" ]]; then
    warn "Directory '${PROJECT_NAME}' already exists."
    read -rp "$(echo -e ${YELLOW}"Overwrite it? [y/N]: "${RESET})" overwrite
    if [[ "${overwrite,,}" != "y" ]]; then
      error "Setup cancelled by user."
      exit 0
    fi
    rm -rf "$PROJECT_DIR"
    info "Removed existing directory."
  fi

  mkdir -p "${PROJECT_DIR}/Helpers"
  mkdir -p "${PROJECT_DIR}/reports"
  success "Created: ${PROJECT_NAME}/"
  success "Created: ${PROJECT_NAME}/Helpers/"
  success "Created: ${PROJECT_NAME}/reports/"

  # Copy source files
  if [[ -f "${SCRIPT_DIR}/attendance_checker.py" ]]; then
    cp "${SCRIPT_DIR}/attendance_checker.py" "${PROJECT_DIR}/attendance_checker.py"
    success "Copied:  attendance_checker.py"
  else
    error "Source file not found: attendance_checker.py"
    exit 1
  fi

  if [[ -f "${SCRIPT_DIR}/assets.csv" ]]; then
    cp "${SCRIPT_DIR}/assets.csv" "${PROJECT_DIR}/Helpers/assets.csv"
    success "Copied:  Helpers/assets.csv"
  else
    error "Source file not found: assets.csv"
    exit 1
  fi

  if [[ -f "${SCRIPT_DIR}/config.json" ]]; then
    cp "${SCRIPT_DIR}/config.json" "${PROJECT_DIR}/Helpers/config.json"
    success "Copied:  Helpers/config.json"
  else
    error "Source file not found: config.json"
    exit 1
  fi

  # Create blank reports.log
  echo "# Attendance Reports Log" > "${PROJECT_DIR}/reports/reports.log"
  success "Created: reports/reports.log"
}

# =============================================================================
# SECTION 4 — DYNAMIC CONFIGURATION (sed in-place edit)
# =============================================================================
configure_thresholds() {
  echo ""
  echo -e "${BOLD}Step 3 of 4 — Attendance Threshold Configuration${RESET}"
  echo "────────────────────────────────────────"

  local config_file="${PROJECT_DIR}/Helpers/config.json"

  info "Current thresholds in config.json:"
  grep -E '"warning"|"failure"' "$config_file" | sed 's/^/         /'

  echo ""
  read -rp "$(echo -e ${YELLOW}"Do you want to update the attendance thresholds? [y/N]: "${RESET})" update_choice

  if [[ "${update_choice,,}" != "y" ]]; then
    info "Keeping default thresholds (Warning: 75%, Failure: 50%)."
    return
  fi

  while true; do
    read -rp "$(echo -e ${YELLOW}"  Enter new WARNING threshold % (default 75, must be > failure): "${RESET})" new_warning
    new_warning="${new_warning:-75}"
    if [[ ! "$new_warning" =~ ^[0-9]+$ ]] || (( new_warning < 1 || new_warning > 100 )); then
      warn "Please enter a whole number between 1 and 100."
    else
      break
    fi
  done

  while true; do
    read -rp "$(echo -e ${YELLOW}"  Enter new FAILURE threshold % (default 50, must be < warning): "${RESET})" new_failure
    new_failure="${new_failure:-50}"
    if [[ ! "$new_failure" =~ ^[0-9]+$ ]] || (( new_failure < 1 || new_failure > 100 )); then
      warn "Please enter a whole number between 1 and 100."
    elif (( new_failure >= new_warning )); then
      warn "Failure threshold (${new_failure}) must be strictly less than warning threshold (${new_warning})."
    else
      break
    fi
  done

  if sed --version &>/dev/null 2>&1; then
    sed -i "s/\"warning\": [0-9]*/\"warning\": ${new_warning}/" "$config_file"
    sed -i "s/\"failure\": [0-9]*/\"failure\": ${new_failure}/" "$config_file"
  else
    sed -i '' "s/\"warning\": [0-9]*/\"warning\": ${new_warning}/" "$config_file"
    sed -i '' "s/\"failure\": [0-9]*/\"failure\": ${new_failure}/" "$config_file"
  fi

  success "config.json updated:"
  grep -E '"warning"|"failure"' "$config_file" | sed 's/^/         /'
}

# =============================================================================
# SECTION 5 — ENVIRONMENT VALIDATION (Health Check)
# =============================================================================
run_health_check() {
  echo ""
  echo -e "${BOLD}Step 4 of 4 — Environment Health Check${RESET}"
  echo "────────────────────────────────────────"

  echo -ne "  Checking python3 installation… "
  if command -v python3 &>/dev/null; then
    PY_VERSION=$(python3 --version 2>&1)
    echo -e "${GREEN}FOUND${RESET} (${PY_VERSION})"
  else
    echo -e "${RED}NOT FOUND${RESET}"
    warn "python3 is not installed. The attendance tracker requires Python 3."
  fi

  echo ""
  info "Verifying project directory structure…"

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
      echo -e "  ${GREEN}✔${RESET}  ${rel_path}"
    else
      echo -e "  ${RED}✘${RESET}  ${rel_path}  ${RED}← MISSING${RESET}"
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

# =============================================================================
# SECTION 6 — FINAL SUMMARY
# =============================================================================
print_summary() {
  echo ""
  echo -e "${BOLD}${GREEN}"
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║              ✅  Setup Complete!                     ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
  echo -e "  ${BOLD}Project directory:${RESET} ${PROJECT_DIR}"
  echo ""
  echo -e "  ${BOLD}To run the tracker:${RESET}"
  echo -e "    cd ${PROJECT_NAME}"
  echo -e "    python3 attendance_checker.py"
  echo ""
  echo -e "  ${BOLD}To trigger the archive/cleanup feature:${RESET}"
  echo -e "    Press ${BOLD}Ctrl+C${RESET} at any time while this script is running."
  echo ""
}

# =============================================================================
# MAIN
# ===============================
