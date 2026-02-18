#!/bin/bash
###############################################################################
#
# MIT License
#
# Copyright (c) Advanced Micro Devices, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#################################################################################

set -euo pipefail
set -x

############################
# Preliminary setup
############################
export HF_HUB_CACHE="/myworkspace"

SERVER_HOST=0.0.0.0
SERVER_PORT=8000
SERVER_URL="http://127.0.0.1:${SERVER_PORT}/v1/models"

############################
# Dependencies
############################
pip install -qqq lm-eval[api]
apt-get update -qq
apt-get install -y curl vim

############################
# Clone benchmark repo
############################
if [[ ! -d bench_serving ]]; then
  git clone https://github.com/kimbochen/bench_serving.git
fi

############################
# Start GPT-OSS server
############################
echo "[INFO] Starting GPT-OSS server..."

python3 -m atom.entrypoints.openai_server \
  --model openai/gpt-oss-120b \
  -tp 8 \
  --kv_cache_dtype fp8 \
  --host ${SERVER_HOST} \
  --port ${SERVER_PORT} \
  > server.log 2>&1 &

SERVER_PID=$!
echo "[INFO] Server PID: ${SERVER_PID}"

cleanup() {
  echo "[INFO] Shutting down server..."
  kill ${SERVER_PID} 2>/dev/null || true
}
trap cleanup EXIT INT TERM

############################
# Wait for readiness
############################
echo "[INFO] Waiting for server to be ready..."
until curl -sf ${SERVER_URL} >/dev/null; do
  sleep 2
done
echo "[INFO] Server is ready."

############################
# Inline benchmark client
############################
MODEL="/it-share/gpt-oss-120b"
ISL_VALUES=(1)
OSL=1000
CONC_VALUES=(2 4 8 16 32 64 128 256 512)
RESULT_FILENAME=result

for ISL in "${ISL_VALUES[@]}"; do
  for CONC in "${CONC_VALUES[@]}"; do
    echo "[INFO] ISL=${ISL}, CONC=${CONC}"
    python bench_serving/benchmark_serving.py \
      --backend=vllm \
      --base-url="http://localhost:${SERVER_PORT}" \
      --endpoint=/v1/completions \
      --model="${MODEL}" \
      --dataset-name=random \
      --random-input-len="${ISL}" \
      --random-output-len="${OSL}" \
      --num-prompts=$(( CONC * 4 )) \
      --max-concurrency="${CONC}" \
      --random-range-ratio 1.0 \
      --request-rate=inf \
      --ignore-eos \
      --save-result \
      --percentile-metrics="ttft,tpot,itl,e2el" \
      --result-dir=./ \
      --result-filename="${RESULT_FILENAME}_isl${ISL}_conc${CONC}.json"
  done
done

echo "[INFO] Benchmark finished."
