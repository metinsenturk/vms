#!/usr/bin/env bash
set -euo pipefail

print_kv() {
  local key="$1"
  local value="$2"
  printf "%-24s %s\n" "$key" "$value"
}

first_ipv4() {
  ip -4 -o addr show scope global \
    | awk '{print $4}' \
    | cut -d/ -f1 \
    | head -n1
}

all_ipv4() {
  ip -4 -o addr show scope global \
    | awk '{print $4}' \
    | cut -d/ -f1 \
    | paste -sd',' -
}

os_pretty="unknown"
if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  os_pretty="${PRETTY_NAME:-unknown}"
fi

cpu_model="$(awk -F: '/model name/ {gsub(/^ +/, "", $2); print $2; exit}' /proc/cpuinfo || true)"
cpu_count="$(nproc --all 2>/dev/null || echo "unknown")"
mem_mib="$(awk '/MemTotal/ {printf "%.0f", $2/1024}' /proc/meminfo 2>/dev/null || echo "unknown")"
root_usage="$(df -h / | awk 'NR==2 {print $3"/"$2" ("$5")"}')"
uptime_human="$(uptime -p 2>/dev/null || echo "unknown")"
ip_primary="$(first_ipv4 || true)"
ip_all="$(all_ipv4 || true)"

echo "=== VM System Info ==="
print_kv "Hostname" "$(hostname)"
print_kv "FQDN" "$(hostname -f 2>/dev/null || echo "n/a")"
print_kv "OS" "$os_pretty"
print_kv "Kernel" "$(uname -r)"
print_kv "Architecture" "$(uname -m)"
print_kv "Virtualization" "$(systemd-detect-virt 2>/dev/null || echo "unknown")"
print_kv "Uptime" "$uptime_human"

echo
echo "=== User Info ==="
print_kv "Current User" "$(id -un)"
print_kv "UID:GID" "$(id -u):$(id -g)"
print_kv "Groups" "$(id -nG)"
print_kv "Home" "$HOME"
print_kv "Shell" "${SHELL:-unknown}"

echo
echo "=== Network Info ==="
print_kv "Primary IPv4" "${ip_primary:-unknown}"
print_kv "All IPv4" "${ip_all:-unknown}"
print_kv "Default Route" "$(ip route show default | head -n1 | sed 's/^default //')"

echo
echo "=== Resource Info ==="
print_kv "CPU Model" "${cpu_model:-unknown}"
print_kv "vCPU Count" "$cpu_count"
print_kv "Memory (MiB)" "$mem_mib"
print_kv "Root Disk Usage" "$root_usage"

echo
echo "=== Vagrant Context ==="
print_kv "VAGRANT_ENV" "${VAGRANT_ENV:-n/a}"
print_kv "PWD" "$(pwd)"
