"""
rag_build.py — turns a folder of .txt / .pdf files into a local, searchable
vector index. Run this once (and again whenever you add new sources).

Usage:
    python3 rag_build.py

Expects a folder structure like:
    offline-survival-llm/
        corpus/
            fm21-76-survival-manual.txt
            where-there-is-no-doctor.pdf
            my-own-notes.txt
        rag_build.py
        main.py

Produces:
    index.faiss      -- the vector index
    chunks.pkl       -- the text chunks the index points to
"""

import os
import pickle
import re

from sentence_transformers import SentenceTransformer
import faiss
from pypdf import PdfReader

CORPUS_DIR = "corpus"
INDEX_PATH = "index.faiss"
CHUNKS_PATH = "chunks.pkl"
CHUNK_SIZE_WORDS = 200
CHUNK_OVERLAP_WORDS = 40


def read_txt(path):
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        return f.read()


def read_pdf(path):
    reader = PdfReader(path)
    return "\n".join(page.extract_text() or "" for page in reader.pages)


def chunk_text(text, source_name):
    words = re.sub(r"\s+", " ", text).strip().split(" ")
    chunks = []
    step = CHUNK_SIZE_WORDS - CHUNK_OVERLAP_WORDS
    for i in range(0, len(words), step):
        chunk_words = words[i:i + CHUNK_SIZE_WORDS]
        if not chunk_words:
            continue
        chunk = " ".join(chunk_words)
        chunks.append({"text": chunk, "source": source_name})
        if i + CHUNK_SIZE_WORDS >= len(words):
            break
    return chunks


def main():
    if not os.path.isdir(CORPUS_DIR):
        print(f"Create a '{CORPUS_DIR}/' folder and put your .txt/.pdf sources in it first.")
        return

    all_chunks = []
    for root, _dirs, files in os.walk(CORPUS_DIR):
        for fname in sorted(files):
            path = os.path.join(root, fname)
            if fname.lower().endswith(".txt"):
                text = read_txt(path)
            elif fname.lower().endswith(".pdf"):
                text = read_pdf(path)
            else:
                continue
            chunks = chunk_text(text, fname)
            all_chunks.extend(chunks)
            print(f"  {os.path.relpath(path, CORPUS_DIR)}: {len(chunks)} chunks")

    if not all_chunks:
        print("No sources found. Add .txt or .pdf files to corpus/ and re-run.")
        return

    print(f"Total chunks: {len(all_chunks)}")
    print("Loading embedding model (first run downloads ~90MB)...")
    model = SentenceTransformer("all-MiniLM-L6-v2")

    print("Embedding chunks...")
    texts = [c["text"] for c in all_chunks]
    embeddings = model.encode(texts, show_progress_bar=True, convert_to_numpy=True)

    dim = embeddings.shape[1]
    index = faiss.IndexFlatL2(dim)
    index.add(embeddings)

    faiss.write_index(index, INDEX_PATH)
    with open(CHUNKS_PATH, "wb") as f:
        pickle.dump(all_chunks, f)

    print(f"Saved {INDEX_PATH} and {CHUNKS_PATH}. Ready for main.py.")


if __name__ == "__main__":
    main()
