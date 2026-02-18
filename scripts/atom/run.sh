#!/bin/bash
trap '' HUP
set -e
set -x

nohup python3 -m atom.entrypoints.openai_server \
  --model openai/gpt-oss-120b \
  -tp 8 \
  --kv_cache_dtype fp8 \
  --host 0.0.0.0 \
  --port 8000 \
  > server.log 2>&1 &

SERVER_PID=$!

echo "Server running with PID ${SERVER_PID}"

# Block forever so MAD doesn't kill us
wait ${SERVER_PID}
