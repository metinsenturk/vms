#!/usr/bin/env bash
set -euo pipefail

ICON_PASS="✅"
ICON_FAIL="❌"
ICON_WARN="⚠️"
ICON_INFO="ℹ️"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

print_header() {
  local title="$1"
  echo
  echo "=== ${title} ==="
}

report_item() {
  local item="$1"
  local suggested="$2"
  local final="$3"
  local details="$4"
  local icon="$ICON_INFO"

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

safe_cmd() {
  local cmd="$1"
  bash -lc "$cmd" 2>/dev/null || true
}

main() {
  local now
  local host
  local user_name
  local os_pretty="unknown"
  local kernel_name
  local init_system="unknown"
  local is_wsl="false"

  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  host="$(hostname)"
  user_name="$(id -un)"

  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    os_pretty="${PRETTY_NAME:-unknown}"
  fi

  echo "🐳 Docker Health Report"
  echo "${ICON_INFO} Timestamp: ${now}"
  echo "${ICON_INFO} Hostname: ${host}"
  echo "${ICON_INFO} User: ${user_name}"
  echo "${ICON_INFO} OS: ${os_pretty}"
  kernel_name="$(uname -r)"
  echo "${ICON_INFO} Kernel: ${kernel_name}"

  init_system="$(safe_cmd 'ps -p 1 -o comm=')"
  if printf "%s" "${kernel_name}" | tr '[:upper:]' '[:lower:]' | grep -q "microsoft"; then
    is_wsl="true"
  fi

  print_header "Availability Checks"

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

  print_header "Daemon and Service Checks"

  local svc_enabled
  local svc_active
  local svc_details
  svc_enabled="$(safe_cmd 'systemctl is-enabled docker')"
  svc_active="$(safe_cmd 'systemctl is-active docker')"
  svc_details="enabled=${svc_enabled:-unknown}, active=${svc_active:-unknown}, init=${init_system:-unknown}, wsl=${is_wsl}"

  local svc_status="WARN"
  if [[ "${svc_active}" == "active" ]]; then
    svc_status="PASS"
  elif [[ -z "${svc_active}" ]]; then
    svc_status="WARN"
  else
    svc_status="FAIL"
  fi

  local daemon_status="FAIL"
  local daemon_summary="docker info unavailable"
  if [[ "${docker_cmd_status}" == "PASS" ]]; then
    if docker info >/dev/null 2>&1; then
      daemon_status="PASS"
      daemon_summary="$(docker info --format 'Server={{.ServerVersion}}, Driver={{.Driver}}, Cgroup={{.CgroupDriver}}/{{.CgroupVersion}}, Containers={{.Containers}} (running={{.ContainersRunning}} paused={{.ContainersPaused}} stopped={{.ContainersStopped}}), Logging={{.LoggingDriver}}' 2>/dev/null || echo 'daemon reachable')"
    fi
  fi

  report_item \
    "Docker Daemon Reachability" \
    "docker info succeeds" \
    "${daemon_status}" \
    "${daemon_summary}"

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

  print_header "Access and Runtime Checks"

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

  local group_status="WARN"
  if id -nG "${user_name}" | grep -qw docker; then
    group_status="PASS"
  fi
  report_item \
    "User Docker Group" \
    "current user is in docker group" \
    "${group_status}" \
    "groups=$(id -nG "${user_name}")"

  local user_access_status="FAIL"
  if docker ps >/dev/null 2>&1; then
    user_access_status="PASS"
  fi
  report_item \
    "User-Level Docker Access" \
    "docker ps works without sudo" \
    "${user_access_status}" \
    "checked as user ${user_name}"

  local runtime_status="WARN"
  local runtime_details="runtime test skipped"
  if [[ "${daemon_status}" == "PASS" && "${user_access_status}" == "PASS" ]]; then
    if docker image inspect hello-world >/dev/null 2>&1; then
      if docker run --rm --pull=never hello-world >/dev/null 2>&1; then
        runtime_status="PASS"
        runtime_details="hello-world ran with --pull=never"
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

  print_header "Additional Diagnostics"
  echo "${ICON_INFO} docker system df:"
  safe_cmd "docker system df --format 'type={{.Type}} total={{.TotalCount}} active={{.Active}} size={{.Size}} reclaimable={{.Reclaimable}}'" | sed 's/^/   /'

  local docker_warnings
  docker_warnings="$(safe_cmd 'docker info --format "{{json .Warnings}}"')"
  if [[ -n "${docker_warnings}" && "${docker_warnings}" != "null" && "${docker_warnings}" != "[]" ]]; then
    echo "${ICON_WARN} docker info warnings: ${docker_warnings}"
  else
    echo "${ICON_INFO} docker info warnings: none"
  fi

  print_header "Final Summary"
  echo "${ICON_PASS} PASS: ${PASS_COUNT}"
  echo "${ICON_WARN} WARN: ${WARN_COUNT}"
  echo "${ICON_FAIL} FAIL: ${FAIL_COUNT}"

  if [[ ${FAIL_COUNT} -gt 0 ]]; then
    echo "${ICON_FAIL} OVERALL FINAL: FAIL"
    exit 1
  fi

  echo "${ICON_PASS} OVERALL FINAL: PASS"
}

main
