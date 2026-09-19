# Subtitles: fp16 encoder

Status (2026-08-26): **auto-selected and validated.** The worker picks fp16
when the adapter exposes `shader-f16` and fp32 otherwise (Chromium on
Linux). Root cause of the historical empty-string failure is diagnosed
below. The fp16 path is validated end-to-end on real f16 hardware via
Firefox on Linux (`STT_BROWSER=firefox` in the smoke harness), which —
unlike Chromium — exposes `shader-f16` there.

## Why we want it

The Parakeet encoder runs on WebGPU in fp32 today:

- Weights: `encoder-model.onnx.data` is ~2.4 GB in fp32; an fp16 encoder is
  ~1.2 GB — half the download, disk cache, and resident VRAM.
- Activations: onnxruntime-web's WebGPU execution provider keeps every freed
  GPU buffer in a size-keyed free list for the lifetime of the session (no
  eviction, no return to the driver). Since utterances arrive in many
  distinct lengths, the pool converges to the union of all activation-buffer
  sizes ever seen — observed growing from ~3.2 GB to ~5.5 GB over an hour of
  live captioning. fp16 would halve every one of those buffers, on top of
  halving the weights.

On low-VRAM devices (e.g. 8 GB shared with the compositor and video decode)
the fp32 footprint risks driver paging (massive slowdown) and eventually
WebGPU device loss.

## Symptom

With an fp16 encoder, transcription **silently returns empty strings** on
some machines — no error, no rejected promise, just blank output. The
upstream demo (<https://ysdede.github.io/keet/>) shows the same failure
here. This is noted in `src/stt-worker/worker.js` next to the
`encoderQuant` default.

## Root cause (diagnosed 2026-08-25)

Three findings, established empirically on a Linux machine that reproduces
the failure (RTX 5090, NVIDIA 610.57.04, Chromium 151):

1. **Chromium on Linux does not expose the WebGPU `shader-f16` feature at
   all** — on any GPU. The Vulkan driver advertises `shaderFloat16` and
   16-bit storage, but the adapter's feature set lacks `shader-f16`, and no
   flag (`--enable-dawn-features`, `--enable-blink-features`,
   `--enable-webgpu-developer-features`) turns it on. Per the Chromium
   intent-to-ship for WebGPU f16, the feature shipped on macOS/ChromeOS
   first and on Windows behind the DXC migration; Linux never got it.
   "Works on some machines, fails on others" is **feature availability by
   platform**, not driver numerics. (Firefox's WebGPU on the same
   machine/driver _does_ expose `shader-f16` — the gap is Chromium's, not
   Vulkan's.)
2. **onnxruntime-web runs fp16 models anyway when the feature is missing.**
   The JSEP WebGPU EP requests `shader-f16` on the device and prepends
   `enable f16;` to WGSL _only if the adapter has it_, but never refuses an
   fp16 model when it doesn't — execution proceeds and produces garbage
   encodings, the decoder emits nothing, and no error surfaces. (Upstream
   bug worth filing: this should be a hard error or a fallback.)
3. **The fp16 exports themselves are numerically fine.** On the CPU EP,
   both `grikdotnet/parakeet-tdt-0.6b-fp16` (full fp16, fp32 IO) and our
   own mixed-precision exports match the fp32 encoder to cosine similarity
   ≥ 0.999998 with zero NaN/Inf.

The earlier overflow hypothesis is **disproved** for this model: scanning
all float intermediates of the fp32 encoder over speech fixtures
(`scripts/scan_overflow.py`) shows a global max |activation| of exactly
10000.0 (the attention-mask fill constant) — far inside fp16's 65504 range.
The transformers.js Whisper issue we cited
(<https://github.com/huggingface/transformers.js/issues/1590>) is a
different failure class.

Community fp16 exports, for the record: `grikdotnet/parakeet-tdt-0.6b-fp16`
(numerically clean, CUDA-validated only) and
`Olicorne/parakeet-tdt-0.6b-v3-optimized-onnx` (fp16 files were a naive
cast, withdrawn by the author 2026-08-23; repo remains interesting for its
sharded fp32 encoder). Neither fails because of how it was exported — any
fp16 export fails wherever `shader-f16` is unavailable.

## Current behavior

The worker (`src/stt-worker/worker.js`) resolves the encoder precision at
init: an explicit `encoderQuant` of `"fp16"`/`"fp32"` is honored (the smoke
harness forces it via `STT_ENCODER_QUANT`), anything else auto-selects via
`adapter.features.has("shader-f16")`. fp16 loads the self-contained
`encoder-model.fp16.onnx` from our model repo (fp32 IO, so parakeet.js's
float32 feeds work unchanged); fp32 keeps the sidecar pair. Today that
means fp16 for macOS/ChromeOS/newer-Windows Chrome, fp32 for all of Linux.

Verified both ways on the same machine (RTX 5090):

- Chromium (no `shader-f16`): auto picks fp32 and transcribes; forced fp16
  reproduces the empty-string failure, as expected.
- Firefox (`shader-f16` exposed): auto picks fp16 and the full smoke
  harness passes — correct transcription and VAD utterances with the
  shipped `encoder-model.fp16.onnx`.

## Still open

1. Consider an init warm-up canary (a fixture must transcribe to non-empty
   text, else re-init as fp32) as a belt-and-braces fallback for genuinely
   broken f16 drivers.
2. Watch for Chromium enabling `shader-f16` on Linux, and consider filing
   the ORT-web silent-execution bug upstream.
3. The f16 kernels are only exercised on Firefox/Vulkan so far; Chromium's
   Metal/D3D backends (where it will actually run fp16 in production) run
   the same ORT WGSL but haven't been checked by us directly.

Note: int8/fp8 are not alternatives for the encoder — WGSL has no 8-bit
types (only packed DP4a-style dot products), ORT-web falls back off the
WebGPU EP for quantized encoder ops (parakeet.js upgrades int8 encoder
requests to fp32 on WebGPU backends), and fp8 does not exist in WebGPU at
all. The int8 decoder already runs on WASM, unaffected.

## Reproducing the diagnosis

Checking any adapter takes one line in a devtools console:

```js
(await navigator.gpu.requestAdapter()).features.has("shader-f16");
```

The numeric findings came from running candidate encoders on
onnxruntime's CPU EP against the fp32 reference (same mel input, compare
outputs for NaN/Inf and cosine similarity), and from running the fp32
encoder with all intermediates exposed as graph outputs to scan activation
ranges. Mixed-precision exports were produced with onnxconverter-common's
`convert_float_to_float16` (`keep_io_types=True`); none of that tooling is
needed going forward, since the shipped fp16 file already exists in the
model repo.

The smoke harness (`scripts/smoke-stt-worker.mjs` in the
discourse_voice_assets gem repository) now logs the adapter and
launches Chromium with `Vulkan,VulkanFromANGLE,DefaultANGLEVulkan` —
without the FromANGLE pair, headless Chromium silently falls back to
SwiftShader (CPU rasterizer, no `shader-f16`, ~1000× slower encode), which
is both a useless benchmark and an accidental repro of the no-f16 failure.

## How to test

The smoke harness exercises the real worker in headless Chromium; point it
at a directory containing candidate files (the worker fetches
`encoder-model.onnx`, `encoder-model.onnx.data` — a zero-byte file works
for self-contained encoders — `decoder_joint-model.int8.onnx`, `vocab.txt`):

```bash
flite -t "the quick brown fox jumps over the lazy dog" /tmp/fix.wav
STT_MODEL_DIR=/path/to/model-dir node scripts/smoke-stt-worker.mjs /tmp/fix.wav
```

Check the `adapter:` line in the output: on an adapter without
`shader-f16`, an fp16-encoder FAIL only reproduces the availability bug and
says nothing about the export's numerics. Use `STT_SMOKE_PORT` to give each
model dir its own origin, since downloads are cached per-origin in the
persistent profile.

To exercise the fp16 path on Linux, run the harness in Firefox — the only
browser exposing `shader-f16` here (WebGPU is enabled via prefs in a
separate persistent profile):

```bash
STT_BROWSER=firefox STT_MODEL_DIR=/path/to/model-dir \
  node scripts/smoke-stt-worker.mjs /tmp/fix.wav
```

The model dir needs `encoder-model.fp16.onnx` (self-contained; a zero-byte
`encoder-model.onnx.data` still satisfies the fp32 branch if you force it)
— auto-select picks fp16 there and the whole chain should PASS.
