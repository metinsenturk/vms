#!/bin/bash
set -euo pipefail

MODEL="llama3.2:1b"
MARKER="/var/tmp/ollama-model-llama3.2-1b.ok"

if [ -f "$MARKER" ]; then
  echo "Model ${MODEL} already pulled, skipping."
  exit 0
fi

echo "==> Waiting for Ollama API to become available..."
RETRIES=24
for i in $(seq 1 "$RETRIES"); do
  if curl -sf http://localhost:11434 > /dev/null 2>&1; then
    echo "==> Ollama API is ready."
    break
  fi
  if [ "$i" -eq "$RETRIES" ]; then
    echo "ERROR: Ollama API did not become available after $((RETRIES * 5)) seconds." >&2
    exit 1
  fi
  echo "    Attempt $i/$RETRIES — waiting 5 s..."
  sleep 5
done

# Skip pull if the model is already present (e.g. restored from snapshot).
if ollama list 2>/dev/null | grep -q "^llama3.2:1b"; then
  echo "==> Model ${MODEL} already present in Ollama, skipping pull."
else
  echo "==> Pulling model ${MODEL} (this may take several minutes)..."
  ollama pull "$MODEL"
  echo "==> Model ${MODEL} ready."
fi

touch "$MARKER"
echo "==> Done."
