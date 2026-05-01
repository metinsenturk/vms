#!/bin/bash
set -euo pipefail

MODEL="llama3.2:1b"

echo "==> [status] Ollama"
echo "------------------------------------------------------------"

# Binary presence
if command -v ollama > /dev/null 2>&1; then
  VERSION=$(ollama --version 2>/dev/null || echo "unknown")
  echo "  binary   : $(command -v ollama)"
  echo "  version  : $VERSION"
else
  echo "  binary   : NOT FOUND"
fi

# systemd service state
if systemctl list-units --full --all | grep -q "ollama.service"; then
  SVC_STATUS=$(systemctl is-active ollama 2>/dev/null || true)
  SVC_ENABLED=$(systemctl is-enabled ollama 2>/dev/null || true)
  echo "  service  : $SVC_STATUS (enabled: $SVC_ENABLED)"
else
  echo "  service  : ollama.service not found"
fi

# API reachability
if curl -sf --max-time 3 http://localhost:11434 > /dev/null 2>&1; then
  echo "  api      : http://localhost:11434 reachable"
else
  echo "  api      : http://localhost:11434 NOT reachable"
fi

# Model presence
if command -v ollama > /dev/null 2>&1; then
  if ollama list 2>/dev/null | grep -q "^${MODEL}"; then
    echo "  model    : ${MODEL} present"
  else
    echo "  model    : ${MODEL} NOT found"
  fi
else
  echo "  model    : cannot check (ollama binary missing)"
fi

echo "------------------------------------------------------------"
