#!/bin/bash
set -euo pipefail

OPENFANG_BIN="$HOME/.openfang/bin/openfang"

echo "==> [status] OpenFang"
echo "------------------------------------------------------------"

# Binary presence
if [ -x "$OPENFANG_BIN" ]; then
  VERSION=$("$OPENFANG_BIN" --version 2>/dev/null || echo "unknown")
  echo "  binary   : $OPENFANG_BIN"
  echo "  version  : $VERSION"
else
  echo "  binary   : NOT FOUND at $OPENFANG_BIN"
fi

# systemd service state (is-active returns "inactive"/"activating"/"active"/"failed";
# is-enabled returns "enabled"/"disabled"/"not-found" — reliable regardless of load state)
SVC_STATUS=$(systemctl is-active openfang 2>/dev/null || true)
SVC_ENABLED=$(systemctl is-enabled openfang 2>/dev/null || true)
echo "  service  : ${SVC_STATUS:-unknown} (enabled: ${SVC_ENABLED:-unknown})"

# HTTP reachability (port 4200)
if curl -sf --max-time 3 http://127.0.0.1:4200 > /dev/null 2>&1; then
  echo "  port     : 4200 reachable"
else
  echo "  port     : 4200 NOT reachable"
fi

echo "------------------------------------------------------------"
