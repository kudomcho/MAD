import subprocess
import time
import signal
import sys
import requests
from pathlib import Path

# -----------------------
# Configuration
# -----------------------
MODEL_PATH = "openai/gpt-oss-120b"
TP = 8
PORT = 8000

ISL_VALUES = [1]
OSL = 1000
CONC_VALUES = [2, 4, 8, 16, 32, 64, 128, 256, 512]
RESULT_PREFIX = "result"

SERVER_CMD = [
    sys.executable, "-m", "atom.entrypoints.openai_server",
    "--model", MODEL_PATH,
    "-tp", str(TP),
    "--kv_cache_dtype", "fp8",
    "--host", "0.0.0.0",
    "--port", str(PORT),
]

BASE_URL = f"http://localhost:{PORT}"
MODELS_ENDPOINT = f"{BASE_URL}/v1/models"

# -----------------------
# Helpers
# -----------------------
def wait_for_server(timeout=1800, interval=5):
    start = time.time()
    while time.time() - start < timeout:
        try:
            r = requests.get(MODELS_ENDPOINT, timeout=2)
            if r.status_code == 200:
                print("[OK] Atom server is ready")
                return True
        except Exception:
            pass
        print("[WAIT] Waiting for Atom server...")
        time.sleep(interval)
    return False


def run_client():
    for isl in ISL_VALUES:
        for conc in CONC_VALUES:
            out_file = f"{RESULT_PREFIX}_isl{isl}_conc{conc}.json"

            cmd = [
                sys.executable, "bench_serving/benchmark_serving.py",
                "--backend", "vllm",
                "--base-url", BASE_URL,
                "--endpoint", "/v1/completions",
                "--model", MODEL_PATH,
                "--dataset-name", "random",
                "--random-input-len", str(isl),
                "--random-output-len", str(OSL),
                "--num-prompts", str(conc * 4),
                "--max-concurrency", str(conc),
                "--random-range-ratio", "1.0",
                "--request-rate", "inf",
                "--ignore-eos",
                "--save-result",
                "--percentile-metrics", "ttft,tpot,itl,e2el",
                "--result-dir", ".",
                "--result-filename", out_file,
            ]

            print(f"[RUN] ISL={isl} CONC={conc}")
            subprocess.run(cmd, check=True)


# -----------------------
# Main
# -----------------------
def main():
    print("[START] Launching Atom server")
    server = subprocess.Popen(
        SERVER_CMD,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )

    try:
        if not wait_for_server():
            raise RuntimeError("Atom server failed to start")

        run_client()
        print("[DONE] All benchmarks finished")

    finally:
        print("[CLEANUP] Shutting down Atom server")
        try:
            server.send_signal(signal.SIGINT)
            server.wait(timeout=60)
        except Exception:
            server.kill()


if __name__ == "__main__":
    main()
