#!/bin/bash
trap '' HUP
set -e
set -x

command -v curl >/dev/null || {
  echo "[ERROR] curl not found"
  exit 1
}

if [[ ! -d bench_serving ]]; then
  git clone https://github.com/kimbochen/bench_serving.git
fi

nohup python3 -m atom.entrypoints.openai_server \
  --model openai/gpt-oss-120b \
  -tp 8 \
  --kv_cache_dtype fp8 \
  --host 0.0.0.0 \
  --port 8000 \
  > server.log 2>&1 &

SERVER_PID=$!

for i in {1..300}; do
  if curl -sf http://127.0.0.1:8000/v1/models >/dev/null; then
    break
  fi
  sleep 2
done

if ! curl -sf http://127.0.0.1:8000/v1/models >/dev/null; then
  echo "[ERROR] Server failed to start"
  kill "${SERVER_PID}" || true
  exit 1
fi

# ---- RUN BENCHMARK HERE ----
python bench_serving/benchmark_serving.py ...

# ---- Cleanup ----
kill "${SERVER_PID}" || true

OUTPUT_CSV="perf_gpt-oss-120b.csv"
if [[ -f "$OUTPUT_CSV" ]]; then
  mv "$OUTPUT_CSV" ../
fi
