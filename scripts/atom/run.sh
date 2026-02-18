#!/bin/bash
###############################################################################
# MIT License
###############################################################################

trap '' HUP
set -e
set -x

# ---- Install deps (ONLY if you really must) ----
# pip install -qqq lm-eval[api]

# ---- Clone benchmark repo ----
if [[ ! -d bench_serving ]]; then
  git clone https://github.com/kimbochen/bench_serving.git
fi

# ---- Start server (detached) ----
nohup python3 -m atom.entrypoints.openai_server \
  --model openai/gpt-oss-120b \
  -tp 8 \
  --kv_cache_dtype fp8 \
  --host 0.0.0.0 \
  --port 8000 \
  > server.log 2>&1 &

SERVER_PID=$!

# ---- Wait for server readiness ----
for i in {1..300}; do
  if curl -sf http://127.0.0.1:8000/v1/models >/dev/null; then
    break
  fi
  sleep 2
done

if ! curl -sf http://127.0.0.1:8000/v1/models >/dev/null; then
  echo "[ERROR] Server failed to start"
  exit 1
fi

# ---- Run your benchmark HERE ----
# python bench_serving/benchmark_serving.py ...

# ---- Cleanup ----
kill "${SERVER_PID}" || true
