#!/usr/bin/env bash
# 
# Docker Health Report Script
# 
# Purpose: Generate a comprehensive health report for Docker installation on the VM.
# This script checks:
#   - CLI tool availability (docker, docker-compose)
#   - Daemon reachability and health
#   - Service state (systemd integration)
#   - User access and permissions
#   - Container runtime functionality
#   - Diagnostics (disk usage, warnings)
#
# Exit Code: 0 if all checks pass; 1 if any check fails
# 
set -euo pipefail

# ============================================================================
# SECTION: Status Icons and Counters
# ============================================================================
# Define emoji icons for different health statuses used in report output
ICON_PASS="✅"
ICON_FAIL="❌"
ICON_WARN="⚠️"
ICON_INFO="ℹ️"

# Counters for final summary report
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# ============================================================================
# SECTION: Helper Functions
# ============================================================================

# Print a formatted section header for logical grouping of report items
print_header() {
  local title="$1"
  echo
  echo "=== ${title} ==="
}

# Output a single health check result with status, suggestion, and details.
# Updates global counters (PASS_COUNT, FAIL_COUNT, WARN_COUNT) based on status.
#
# Arguments:
#   $1 item      - Name of the check being reported
#   $2 suggested - Ideal/expected state
#   $3 final     - Status outcome (PASS, WARN, FAIL)
#   $4 details   - Implementation details or diagnostic info
report_item() {
  local item="$1"
  local suggested="$2"
  local final="$3"
  local details="$4"
  local icon="$ICON_INFO"

  # Select icon and update counter based on final status
  case "$final" in
    PASS)
      icon="$ICON_PASS"
      PASS_COUNT=$((PASS_COUNT + 1))
      ;;
    FAIL)
      icon="$ICON_FAIL"
      FAIL_COUNT=$((FAIL_COUNT + 1))
      ;;
    WARN)
      icon="$ICON_WARN"
      WARN_COUNT=$((WARN_COUNT + 1))
      ;;
  esac

  printf "%s  %s\n" "${icon}" "${item}"
  printf "    %-10s %s\n" "Suggested:" "${suggested}"
  printf "    %-10s %s\n" "Final:" "${final}"
  printf "    %-10s %s\n" "Details:" "${details}"
}

# Execute a command in a safe manner (suppressing errors) for diagnostic queries.
# Used to gracefully handle optional commands that may not be available.
#
# Arguments:
#   $1 cmd - Shell command to execute
# Returns: Command output if successful, empty string on failure (no error exit)
safe_cmd() {
  local cmd="$1"
  bash -lc "$cmd" 2>/dev/null || true
}

# ============================================================================
# SECTION: Main Report Logic
# ============================================================================

main() {
  # Declare report metadata variables
  local now
  local host
  local user_name
  local os_pretty="unknown"
  local kernel_name
  local init_system="unknown"
  local is_wsl="false"

  # Collect system environment information
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  host="$(hostname)"
  user_name="$(id -un)"

  # Parse /etc/os-release for distribution details
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    os_pretty="${PRETTY_NAME:-unknown}"
  fi

  # Print report header with system context
  echo "🐳 Docker Health Report"
  echo "${ICON_INFO} Timestamp: ${now}"
  echo "${ICON_INFO} Hostname: ${host}"
  echo "${ICON_INFO} User: ${user_name}"
  echo "${ICON_INFO} OS: ${os_pretty}"
  kernel_name="$(uname -r)"
  echo "${ICON_INFO} Kernel: ${kernel_name}"

  # Detect init system and WSL environment for context-aware checks
  init_system="$(safe_cmd 'ps -p 1 -o comm=')"
  if printf "%s" "${kernel_name}" | tr '[:upper:]' '[:lower:]' | grep -q "microsoft"; then
    is_wsl="true"
  fi

  # ========================================================================
  # Availability Checks: Verify Docker CLI tools are installed and functional
  # ========================================================================
  print_header "Availability Checks"

  # Check: Docker CLI binary is reachable
  local docker_cmd_status="FAIL"
  local docker_version="not installed"
  if command -v docker >/dev/null 2>&1; then
    docker_cmd_status="PASS"
    docker_version="$(safe_cmd 'docker --version')"
  fi
  report_item \
    "Docker CLI" \
    "docker command is available" \
    "${docker_cmd_status}" \
    "${docker_version}"

  # Check: Docker Compose plugin is available (only tested if CLI exists)
  local compose_status="FAIL"
  local compose_version="not available"
  if [[ "${docker_cmd_status}" == "PASS" ]]; then
    if docker compose version >/dev/null 2>&1; then
      compose_status="PASS"
      compose_version="$(safe_cmd 'docker compose version')"
    fi
  fi
  report_item \
    "Docker Compose Plugin" \
    "docker compose command responds" \
    "${compose_status}" \
    "${compose_version}"

  # ========================================================================
  # Daemon and Service Checks: Verify Docker daemon is running and reachable
  # ========================================================================
  print_header "Daemon and Service Checks"

  # Query systemd for service state
  local svc_enabled
  local svc_active
  local svc_details
  svc_enabled="$(safe_cmd 'systemctl is-enabled docker')"
  svc_active="$(safe_cmd 'systemctl is-active docker')"
  svc_details="enabled=${svc_enabled:-unknown}, active=${svc_active:-unknown}, init=${init_system:-unknown}, wsl=${is_wsl}"

  # Evaluate service status: PASS only if active, FAIL if inactive, WARN if unknown
  local svc_status="WARN"
  if [[ "${svc_active}" == "active" ]]; then
    svc_status="PASS"
  elif [[ -z "${svc_active}" ]]; then
    svc_status="WARN"
  else
    svc_status="FAIL"
  fi

  # Check: Daemon reachability via user or sudo (tracks access mode for downstream checks)
  # Distinguishes between:
  #   - "user": Current session has docker group membership
  #   - "sudo": Daemon healthy but accessible only via sudo (session group membership stale)
  #   - "none": Daemon not reachable
  local daemon_status="FAIL"
  local daemon_summary="docker info unavailable"
  local daemon_access_mode="none"
  if [[ "${docker_cmd_status}" == "PASS" ]]; then
    if docker info >/dev/null 2>&1; then
      daemon_status="PASS"
      daemon_access_mode="user"
      daemon_summary="$(docker info --format 'Server={{.ServerVersion}}, Driver={{.Driver}}, Cgroup={{.CgroupDriver}}/{{.CgroupVersion}}, Containers={{.Containers}} (running={{.ContainersRunning}} paused={{.ContainersPaused}} stopped={{.ContainersStopped}}), Logging={{.LoggingDriver}}' 2>/dev/null || echo 'daemon reachable')"
    elif sudo -n docker info >/dev/null 2>&1; then
      daemon_status="PASS"
      daemon_access_mode="sudo"
      daemon_summary="$(sudo -n docker info --format 'Server={{.ServerVersion}}, Driver={{.Driver}}, Cgroup={{.CgroupDriver}}/{{.CgroupVersion}}, Containers={{.Containers}} (running={{.ContainersRunning}} paused={{.ContainersPaused}} stopped={{.ContainersStopped}}), Logging={{.LoggingDriver}}' 2>/dev/null || echo 'daemon reachable via sudo'); current session cannot access docker without sudo"
    fi
  fi

  report_item \
    "Docker Daemon Reachability" \
    "docker info succeeds" \
    "${daemon_status}" \
    "${daemon_summary}"

  # Adjust service status for non-systemd environments (WSL, containers without systemd)
  if [[ "${daemon_status}" == "PASS" && "${svc_status}" == "FAIL" ]]; then
    if [[ "${is_wsl}" == "true" || "${init_system}" != "systemd" ]]; then
      svc_status="WARN"
      svc_details="${svc_details}; daemon reachable, service managed outside systemd"
    fi
  fi

  report_item \
    "Docker Service State" \
    "service is active and enabled" \
    "${svc_status}" \
    "${svc_details}"

  # ========================================================================
  # Access and Runtime Checks: Verify user permissions and container execution
  # ========================================================================
  print_header "Access and Runtime Checks"

  # Check: Docker socket exists and has proper permissions
  local socket_details
  socket_details="$(safe_cmd 'stat -c "%n owner=%U group=%G mode=%a" /var/run/docker.sock')"
  local socket_status="WARN"
  if [[ -S /var/run/docker.sock ]]; then
    socket_status="PASS"
  fi
  report_item \
    "Docker Socket" \
    "/var/run/docker.sock exists and is a socket" \
    "${socket_status}" \
    "${socket_details:-socket not found}"

  # Check: Current user is in docker group
  local group_status="WARN"
  if id -nG "${user_name}" | grep -qw docker; then
    group_status="PASS"
  fi
  report_item \
    "User Docker Group" \
    "current user is in docker group" \
    "${group_status}" \
    "groups=$(id -nG "${user_name}")"

  # Check: User can run docker commands without sudo
  # Note: May show WARN if daemon is healthy but current session lacks refreshed group membership
  local user_access_status="FAIL"
  local user_access_details="checked as user ${user_name}"
  if docker ps >/dev/null 2>&1; then
    user_access_status="PASS"
  elif [[ "${daemon_access_mode}" == "sudo" ]] && id -nG "${user_name}" | grep -qw docker; then
    user_access_status="WARN"
    user_access_details="checked as user ${user_name}; docker group present but current login session has not refreshed group membership yet"
  fi
  report_item \
    "User-Level Docker Access" \
    "docker ps works without sudo" \
    "${user_access_status}" \
    "${user_access_details}"

  # Check: Container runtime works (execute hello-world if daemon is reachable)
  local runtime_status="WARN"
  local runtime_details="runtime test skipped"
  if [[ "${daemon_status}" == "PASS" && ( "${user_access_status}" == "PASS" || "${daemon_access_mode}" == "sudo" ) ]]; then
    if docker image inspect hello-world >/dev/null 2>&1; then
      if docker run --rm --pull=never hello-world >/dev/null 2>&1; then
        runtime_status="PASS"
        runtime_details="hello-world ran with --pull=never"
      elif [[ "${daemon_access_mode}" == "sudo" ]] && sudo -n docker run --rm --pull=never hello-world >/dev/null 2>&1; then
        runtime_status="WARN"
        runtime_details="hello-world ran via sudo; current session still lacks direct docker access"
      else
        runtime_status="FAIL"
        runtime_details="hello-world image exists but container execution failed"
      fi
    else
      runtime_status="WARN"
      runtime_details="hello-world image not present; skipped pull for durability"
    fi
  fi

  report_item \
    "Container Runtime Test" \
    "a container can run successfully" \
    "${runtime_status}" \
    "${runtime_details}"

  # ========================================================================
  # Additional Diagnostics: Optional supplementary info
  # ========================================================================
  print_header "Additional Diagnostics"
  
  # Display disk usage breakdown for Docker objects
  echo "${ICON_INFO} docker system df:"
  safe_cmd "docker system df --format 'type={{.Type}} total={{.TotalCount}} active={{.Active}} size={{.Size}} reclaimable={{.Reclaimable}}'" | sed 's/^/   /'

  # Display any warnings reported by Docker daemon
  local docker_warnings
  docker_warnings="$(safe_cmd 'docker info --format "{{json .Warnings}}"')"
  if [[ -n "${docker_warnings}" && "${docker_warnings}" != "null" && "${docker_warnings}" != "[]" ]]; then
    echo "${ICON_WARN} docker info warnings: ${docker_warnings}"
  else
    echo "${ICON_INFO} docker info warnings: none"
  fi

  # ========================================================================
  # Final Summary: Report aggregated results
  # ========================================================================
  print_header "Final Summary"
  echo "${ICON_PASS} PASS: ${PASS_COUNT}"
  echo "${ICON_WARN} WARN: ${WARN_COUNT}"
  echo "${ICON_FAIL} FAIL: ${FAIL_COUNT}"

  # Exit with failure code if any checks failed
  if [[ ${FAIL_COUNT} -gt 0 ]]; then
    echo "${ICON_FAIL} OVERALL FINAL: FAIL"
    exit 1
  fi

  echo "${ICON_PASS} OVERALL FINAL: PASS"
}

# Execute main function
main
