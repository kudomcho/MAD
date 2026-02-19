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
set -ex

# ---- Preliminary setup ----
export HF_HUB_CACHE="/myworkspace"

# ---- Parse args ----
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --model_repo) MODEL="$2"; shift ;;
    --config) CONFIG="$2"; shift ;;
    *) echo "Unknown parameter passed: $1"; exit 1 ;;
  esac
  shift
done


# ---- Run Atom server + client orchestrator ----
python3 -u run_atom.py \
  --model "$MODEL" || {
    echo "[ERROR] run_atom.py failed"
    exit 2
}

# ---- (Optional) collect CSV if you added aggregation ----
MODEL_NAME=$(basename "$MODEL")
CSV="perf_${MODEL_NAME}.csv"
if [[ -f "$CSV" ]]; then
  mv "$CSV" ../
fi

