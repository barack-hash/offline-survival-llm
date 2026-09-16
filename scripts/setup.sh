#!/usr/bin/env bash
# Run this ON THE RASPBERRY PI over SSH, while it still has internet access.
# Installs llama.cpp built for ARM64 and downloads a starting model.
set -e

echo "== Installing build dependencies =="
sudo apt update
sudo apt install -y build-essential cmake git python3-pip python3-venv wget

echo "== Cloning and building llama.cpp =="
cd ~
if [ ! -d "llama.cpp" ]; then
  git clone https://github.com/ggerganov/llama.cpp.git
fi
cd llama.cpp
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j"$(nproc)"

echo "== Creating models folder =="
mkdir -p ~/offline-survival-llm/models
cd ~/offline-survival-llm/models

# Phi-3 Mini 3.8B, Q4_K_M quantization — good balance of speed/quality on Pi 5 8GB.
# If this URL ever changes, search Hugging Face for "Phi-3-mini-4k-instruct-gguf".
MODEL_FILE="Phi-3-mini-4k-instruct-q4.gguf"
if [ ! -f "$MODEL_FILE" ]; then
  echo "== Downloading $MODEL_FILE (about 2.3GB) =="
  wget -O "$MODEL_FILE" \
    "https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf"
fi

echo "== Setting up Python environment =="
cd ~/offline-survival-llm
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install sentence-transformers faiss-cpu pypdf llama-cpp-python pyserial rank-bm25

echo "== Quick test =="
# -st (single-turn) is REQUIRED: without it, current llama.cpp builds drop
# into interactive chat mode and hang forever when run non-interactively
# (learned the hard way — see BUILD_LOG 2026-09-15 Phase 2).
~/llama.cpp/build/bin/llama-cli \
  -m ~/offline-survival-llm/models/Phi-3-mini-4k-instruct-q4.gguf \
  -p "How do I start a fire with a bow drill?" \
  -n 128 -st

echo ""
echo "Setup complete. Model and llama.cpp binary are ready."
echo "Next: copy rag_build.py and main.py into ~/offline-survival-llm, add texts to a corpus/ folder, and run rag_build.py."
