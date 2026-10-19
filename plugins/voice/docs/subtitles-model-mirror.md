# Self-hosting the subtitles models (mirror)

By default, live subtitles download their speech-to-text model on first use
from Discourse's HuggingFace repository,
[Discourse/Discourse-STT](https://huggingface.co/Discourse/Discourse-STT).
The plugin pins that repository to a specific commit.

Some sites can't let browsers reach `huggingface.co`, or prefer not to:
airgapped deployments, enterprise networks, or anyone who wants to control
the bytes. They can serve the models themselves and point the
`voice_stt_model_base_url` site setting at their own mirror.

Only the **model weights** are affected. The runtime bundles (worker, VAD,
onnxruntime) are always served from the plugin's own `public/` directory and
need no extra hosting.

## What to mirror

The repository has one folder per model. Each user picks a model in their
voice settings, so mirror every folder. **Keep the folder names and file
names exactly as they are.**

| Folder | Model | Size |
| --- | --- | --- |
| `ultra-q4/` | Parakeet Ultra, 4-bit encoder (default, "Best quality") | ~410 MB |
| `redux-w2a8/` | Parakeet Redux, 2-bit encoder ("Smaller") | ~210 MB |

Every folder holds the same three files:

| File | Purpose |
| --- | --- |
| `encoder-model.onnx` | quantized encoder, a single file (runs on WebGPU) |
| `decoder_joint-model.int8.onnx` | int8 decoder/joint (runs on WASM) |
| `vocab.txt` | tokenizer vocabulary |

To download them, using the commit the plugin pins (see `DEFAULT_MODEL_ROOT`
in `assets/javascripts/discourse/lib/voice/stt-models.js`):

```bash
REV=0862913c8a5c08254d1082747c6443a06e062988
for model in ultra-q4 redux-w2a8; do
  mkdir -p "discourse-stt/$model"
  for f in encoder-model.onnx decoder_joint-model.int8.onnx vocab.txt; do
    curl -L -o "discourse-stt/$model/$f" \
      "https://huggingface.co/Discourse/Discourse-STT/resolve/$REV/$model/$f"
  done
done
```

The models are CC-BY-4.0. The repository's README lists the attribution and
the source of every file.

The plugin requests `<base_url>/<folder>/<file>` and nothing else.

## Hosting requirements

The files are fetched by the **browser**, from a Web Worker on the forum's
origin, not by the Discourse server. So the mirror must be reachable by your
users, and must speak CORS if it lives on a different origin:

- `Access-Control-Allow-Origin: <forum origin>` (or `*`) on every file.
- HTTPS, if the forum is served over HTTPS (mixed content is blocked).
- A correct `Content-Length`, which any static file server sends. It drives
  the download progress shown in the caption overlay. Range requests are
  not needed.
- Long-lived cache headers are recommended, because the files never change.

Example nginx location:

```nginx
location /models/discourse-stt/ {
  root /var/www;
  add_header Access-Control-Allow-Origin "https://forum.example.com";
  add_header Cache-Control "public, max-age=31536000, immutable";
}
```

Then set the site setting (the trailing slash is optional):

```
voice_stt_model_base_url = https://cdn.example.com/models/discourse-stt
```

## Updating a mirror

Browsers keep a durable copy of the model they use and look it up by URL.
If you replace a file at the same URL, users who already have the old copy
keep it.

When the plugin moves to a new model revision, publish the new files under a
new directory and point the setting there. For example, put the revision in
the path: `.../discourse-stt/<rev>/`.

Each browser keeps only one model. Switching models, or changing the mirror
URL, frees the previous copy.

## Verifying a mirror

The end-to-end smoke harness lives in the discourse_voice_assets gem
repository, alongside the shipped worker bundle. It can run against a local
copy of any one model folder:

```bash
flite -t "the quick brown fox jumps over the lazy dog" /tmp/fix.wav
STT_MODEL_DIR=/path/to/discourse-stt/ultra-q4 \
  node scripts/smoke-stt-worker.mjs /tmp/fix.wav
```

Or point it at the mirror itself:

```bash
STT_MODEL_BASE_URL=https://cdn.example.com/models/discourse-stt/ultra-q4 \
  node scripts/smoke-stt-worker.mjs /tmp/fix.wav
```

The harness loads the shipped worker in Chromium (WebGPU required) and fails
unless the fixture transcribes.
