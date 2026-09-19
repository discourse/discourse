# Self-hosting the subtitles model (mirror)

By default, live subtitles download the speech-to-text model on first use
from Discourse's HuggingFace repository
([Discourse/parakeet-tdt-0.6b-v3-onnx](https://huggingface.co/Discourse/parakeet-tdt-0.6b-v3-onnx),
a clone of the upstream `ysdede/parakeet-tdt-0.6b-v3-onnx` export). Sites
that can't (or don't want to) let browsers reach `huggingface.co` —
airgapped deployments, enterprise networks, or anyone who prefers to
control the bytes — can serve the model themselves and point the
`voice_stt_model_base_url` site setting at their own mirror.

Only the **model weights** are affected. The runtime bundles (worker, VAD,
onnxruntime) are always served from the plugin's own `public/` directory and
need no extra hosting.

## What to mirror

Four files from the
[ysdede/parakeet-tdt-0.6b-v3-onnx](https://huggingface.co/ysdede/parakeet-tdt-0.6b-v3-onnx)
repository (models are CC-BY-4.0; keep the repo's attribution requirements in
mind), **keeping their exact filenames**, in a single flat directory:

| File | Size | Purpose |
| --- | --- | --- |
| `encoder-model.onnx` | ~42 MB | fp32 encoder graph (runs on WebGPU) |
| `encoder-model.onnx.data` | ~2.4 GB | encoder weights (external data referenced by the graph — the filename must not change) |
| `decoder_joint-model.int8.onnx` | ~18 MB | int8 decoder/joint (runs on WASM) |
| `vocab.txt` | ~100 KB | tokenizer vocabulary |

```bash
mkdir parakeet-tdt-0.6b-v3
cd parakeet-tdt-0.6b-v3
for f in encoder-model.onnx encoder-model.onnx.data \
         decoder_joint-model.int8.onnx vocab.txt; do
  curl -LO "https://huggingface.co/ysdede/parakeet-tdt-0.6b-v3-onnx/resolve/main/$f"
done
```

No subdirectory structure is required or supported: the plugin requests
`<base_url>/<filename>` for each of the four files, nothing else.

## Hosting requirements

The files are fetched by the **browser** (from a Web Worker on the forum's
origin), not by the Discourse server, so the mirror must be reachable by your
users and must speak CORS if it lives on a different origin:

- `Access-Control-Allow-Origin: <forum origin>` (or `*`) on all four files.
- HTTPS, if the forum is served over HTTPS (mixed content is blocked).
- Correct `Content-Length` (any static file server does this) — it drives
  the download progress shown in the caption overlay, and the ~2.4 GB file
  arrives as one plain GET; resumable/range support is not needed.
- Long-lived cache headers are still recommended (the files are immutable),
  though the browser keeps a durable Cache API copy after the first
  download, so mirrors are only re-hit when that storage is evicted.

Example nginx location:

```nginx
location /models/parakeet-tdt-0.6b-v3/ {
  root /var/www;
  add_header Access-Control-Allow-Origin "https://forum.example.com";
  add_header Cache-Control "public, max-age=31536000, immutable";
}
```

Then set the site setting:

```
voice_stt_model_base_url = https://cdn.example.com/models/parakeet-tdt-0.6b-v3
```

(Trailing slash optional.)

A custom mirror behaves exactly like the default source: streamed download
progress in the caption overlay and a durable Cache API copy on the user's
device.

## Verifying a mirror

The end-to-end smoke harness (in the discourse_voice_assets gem repository,
alongside the shipped worker bundle) can run against a local copy of the
mirror directory:

```bash
flite -t "the quick brown fox jumps over the lazy dog" /tmp/fix.wav
STT_MODEL_DIR=/path/to/parakeet-tdt-0.6b-v3 \
  node scripts/smoke-stt-worker.mjs /tmp/fix.wav
```

It loads the shipped worker in headless Chromium (WebGPU required), serves
the model files from the given directory exactly as a mirror would, and
fails unless the fixture transcribes.
