import { voiceAssetAppUrl, voiceAssetUrl } from "./voice-assets";

// Stable filenames in the discourse_voice_assets gem's stt/ directory.
const STT_WORKER_FILE = "subtitles-worker.js";
const VAD_BUNDLE_FILE = "vad.js";
const ORT_WASM_JS_FILE = "ort/ort-wasm-simd-threaded.jsep.js";
const ORT_WASM_BINARY_FILE = "ort/ort-wasm-simd-threaded.jsep.wasm";
const VAD_ASSET_DIR = "vad/";

// Live subtitles for room participants.
//
// Viewer-side: the user who turns subtitles on runs speech-to-text locally
// on the audio they already receive, so nothing is required from the other
// participants and no audio ever leaves the browser. Each participant's mic
// stream gets its own Silero VAD (finding utterance boundaries); committed
// utterances are transcribed by a single shared Parakeet model living in a
// Web Worker (WebGPU encoder), which serializes jobs across speakers.
//
// The runtime bundles are served from the plugin's public dir and only
// fetched the first time subtitles are enabled; the ~2.5GB model weights
// come from the `voice_stt_model_base_url` source (Discourse's
// HuggingFace model repository by default), kept in a durable Cache API store.

const PREFERENCE_KEY = "voice:subtitles";

// If neither "ready" nor "error" arrives in this window, something wedged
// (e.g. a stalled model download on the last byte); fail like an error so
// the toggle never shows an enabled-but-dead state. Generous because it
// includes the first-run model download.
const READY_TIMEOUT_MS = 30 * 60 * 1000;

// Interim captions: while a speaker keeps talking, the utterance-so-far is
// re-transcribed on a cadence and shown as a provisional line, so long
// sentences don't sit uncaptioned until the speaker pauses. The final
// (speech-end) pass replaces the provisional text.
const VAD_SAMPLE_RATE = 16000;
const INTERIM_MIN_SAMPLES = 1 * VAD_SAMPLE_RATE;
const INTERIM_INTERVAL_SAMPLES = 1.5 * VAD_SAMPLE_RATE;
// Interims re-encode the whole snapshot, so very long monologues slide: only
// the newest audio is transcribed provisionally; the final pass still covers
// the full utterance.
const INTERIM_WINDOW_MAX_SAMPLES = 15 * VAD_SAMPLE_RATE;

// The bundle stays resident after first use so re-enabling is instant.
let vadModulePromise = null;

function sttUrl(file) {
  return voiceAssetUrl(`stt/${file}`);
}

// The one exception: workers must be same-origin, so the (small) worker
// script always loads from the app. Everything it fetches uses sttUrl.
function workerUrl() {
  return voiceAssetAppUrl(`stt/${STT_WORKER_FILE}`);
}

async function loadVadModule() {
  vadModulePromise ||= import(/* @vite-ignore */ sttUrl(VAD_BUNDLE_FILE));
  try {
    return await vadModulePromise;
  } catch (error) {
    // Allow a retry after a transient failure (e.g. offline asset fetch).
    vadModulePromise = null;
    throw error;
  }
}

export default class SubtitlesManager {
  static isSupported() {
    return (
      typeof WebAssembly !== "undefined" &&
      typeof AudioWorkletNode !== "undefined" &&
      typeof Worker !== "undefined" &&
      !!navigator.gpu
    );
  }

  #taps = new Map();
  #enabled = false;
  #epoch = 0;

  #worker = null;
  #workerReady = false;
  #readyTimer = null;
  #jobCounter = 0;
  #utteranceCounter = 0;
  #retracted = new Set();
  // Utterance start wall-clocks, captured at speech start. Kept manager-side
  // (not round-tripped through the worker) and read back when captions
  // arrive, since results lag speech by the transcription latency.
  #utteranceStarts = new Map();
  #modelBaseUrl = null;
  // Set while the worker reports it can't transcribe faster than realtime:
  // interim snapshots are optional work, so they are shed first.
  #interimsSuspended = false;

  #onCaption;
  #onLoadingChange;
  #onProgress;
  #onError;
  #loadVad;
  #createWorker;

  constructor({
    onCaption,
    onLoadingChange,
    onProgress,
    onError,
    // Injectable for tests; production always uses the shipped assets.
    loadVad = loadVadModule,
    createWorker = () => new Worker(workerUrl()),
  }) {
    this.#onCaption = onCaption;
    this.#onLoadingChange = onLoadingChange;
    this.#onProgress = onProgress;
    this.#onError = onError;
    this.#loadVad = loadVad;
    this.#createWorker = createWorker;
  }

  get enabled() {
    return this.#enabled;
  }

  get loading() {
    if (this.#worker && !this.#workerReady) {
      return true;
    }
    for (const tap of this.#taps.values()) {
      if (!tap.ready) {
        return true;
      }
    }
    return false;
  }

  setEnabled(enabled, { modelBaseUrl = null } = {}) {
    this.#modelBaseUrl = modelBaseUrl;
    if (this.#enabled === enabled) {
      return;
    }

    this.#enabled = enabled;
    if (!enabled) {
      this.#epoch++;
      for (const key of [...this.#taps.keys()]) {
        this.#removeTap(key);
      }
      this.#terminateWorker();
      this.#utteranceStarts.clear();
    }
  }

  async attach(roomId, userId, stream) {
    if (!this.#enabled || !stream) {
      return;
    }

    // The model (and its potentially long first download) only starts once
    // there is actually someone to transcribe — never on page load.
    this.#ensureWorker(this.#modelBaseUrl);

    const key = this.#key(roomId, userId);
    const trackId = stream.getAudioTracks()[0]?.id;
    const existing = this.#taps.get(key);
    if (existing?.trackId === trackId) {
      return;
    }
    // A restarted peer connection replaces the audio track inside the same
    // registry stream; the old source node only ever yields silence from
    // that point, so rebuild the tap on the new track.
    if (existing) {
      this.#removeTap(key);
    }

    const epoch = this.#epoch;
    const tap = {
      roomId,
      userId,
      trackId,
      vad: null,
      ready: false,
      speaking: false,
      utteranceId: 0,
      frames: [],
      bufferedSamples: 0,
      samplesSinceInterim: 0,
      interimSent: false,
    };
    this.#taps.set(key, tap);
    this.#onLoadingChange();

    let vadModule;
    try {
      vadModule = await this.#loadVad();
    } catch (error) {
      this.#taps.delete(key);
      this.#onError(error);
      return;
    }

    if (epoch !== this.#epoch || this.#taps.get(key) !== tap) {
      this.#onLoadingChange();
      return;
    }

    let vad;
    try {
      vad = await vadModule.MicVAD.new({
        model: "v5",
        baseAssetPath: sttUrl(VAD_ASSET_DIR),
        // Assigned verbatim to ort's env, which accepts explicit {mjs, wasm}
        // URLs — needed because the module glue ships under a .js name (the
        // .mjs extension gets a non-JavaScript MIME type from nginx).
        onnxWASMBasePath: {
          mjs: sttUrl(ORT_WASM_JS_FILE),
          wasm: sttUrl(ORT_WASM_BINARY_FILE),
        },
        // The "mic" is a remote WebRTC stream the registry owns; the VAD
        // must never stop its tracks when pausing.
        getStream: async () => stream,
        pauseStream: async () => {},
        resumeStream: async () => stream,
        startOnLoad: false,
        onSpeechStart: () => this.#handleSpeechStart(tap, epoch),
        onFrameProcessed: (_probabilities, frame) =>
          this.#handleFrame(tap, epoch, frame),
        onSpeechEnd: (audio) => this.#handleUtterance(tap, epoch, audio),
        onVADMisfire: () => this.#handleMisfire(tap, epoch),
      });
    } catch (error) {
      if (this.#taps.get(key) === tap) {
        this.#removeTap(key);
        this.#onError(error);
      }
      return;
    }

    // A detach or disable may have superseded this tap while the VAD was
    // loading.
    if (epoch !== this.#epoch || this.#taps.get(key) !== tap) {
      this.#teardownVad(vad);
      return;
    }

    tap.vad = vad;
    try {
      await vad.start();
    } catch (error) {
      if (this.#taps.get(key) === tap) {
        this.#removeTap(key);
        this.#onError(error);
      }
      return;
    }

    if (epoch !== this.#epoch || this.#taps.get(key) !== tap) {
      this.#teardownVad(vad);
      return;
    }

    tap.ready = true;
    this.#onLoadingChange();
  }

  detach(roomId, userId) {
    this.#removeTap(this.#key(roomId, userId));
  }

  detachRoom(roomId) {
    for (const [key, tap] of [...this.#taps]) {
      if (Number(tap.roomId) === Number(roomId)) {
        this.#removeTap(key);
      }
    }
  }

  destroy() {
    this.setEnabled(false);
  }

  isPreferred() {
    try {
      return localStorage.getItem(PREFERENCE_KEY) === "1";
    } catch {
      return false;
    }
  }

  setPreference(enabled) {
    try {
      if (enabled) {
        localStorage.setItem(PREFERENCE_KEY, "1");
      } else {
        localStorage.removeItem(PREFERENCE_KEY);
      }
    } catch {
      // ignore storage errors
    }
  }

  #ensureWorker(modelBaseUrl) {
    if (this.#worker) {
      return;
    }

    // Best effort, window-only API: asks the browser to exempt the origin's
    // storage (the multi-GB cached model) from eviction. Chromium decides
    // silently, but Firefox shows a permission prompt — so this must only
    // run here, when transcription is actually starting in a room, never on
    // plain page load.
    navigator.storage?.persist?.().catch(() => {});

    let worker;
    try {
      worker = this.#createWorker();
    } catch (error) {
      this.#onError(error);
      return;
    }

    this.#worker = worker;
    this.#workerReady = false;
    this.#onLoadingChange();

    worker.onmessage = (event) => this.#handleWorkerMessage(worker, event);
    worker.onerror = (event) => {
      if (this.#worker === worker) {
        this.#failWorker(new Error(event.message || "subtitles worker error"));
      }
    };

    this.#readyTimer = setTimeout(() => {
      if (this.#worker === worker && !this.#workerReady) {
        this.#failWorker(new Error("subtitles model load timed out"));
      }
    }, READY_TIMEOUT_MS);

    worker.postMessage({
      type: "init",
      config: {
        modelBaseUrl: modelBaseUrl || null,
        ortWasmJsUrl: sttUrl(ORT_WASM_JS_FILE),
        ortWasmBinaryUrl: sttUrl(ORT_WASM_BINARY_FILE),
      },
    });
  }

  #handleWorkerMessage(worker, event) {
    if (this.#worker !== worker) {
      return;
    }

    const message = event.data || {};
    switch (message.type) {
      case "progress":
        this.#onProgress(message);
        break;
      case "ready":
        clearTimeout(this.#readyTimer);
        this.#workerReady = true;
        this.#onLoadingChange();
        break;
      case "error":
        this.#failWorker(new Error(message.message));
        break;
      case "throughput":
        this.#interimsSuspended = !!message.slow;
        break;
      case "caption": {
        if (!this.#enabled) {
          break;
        }
        // The speaker's tap is gone (they left, or their room was left);
        // captions from jobs still in flight at that point are stale.
        if (!this.#taps.has(this.#key(message.roomId, message.userId))) {
          break;
        }
        // The utterance was retracted (VAD misfire) while this job was in
        // flight; showing its text would resurrect a withdrawn line.
        if (this.#retracted.delete(message.utteranceId)) {
          break;
        }
        const startedAt = this.#utteranceStarts.get(message.utteranceId);
        if (!message.interim) {
          this.#utteranceStarts.delete(message.utteranceId);
        }
        const text = message.text?.trim();
        if (text) {
          this.#onCaption(message.roomId, message.userId, {
            id: message.utteranceId,
            text,
            final: !message.interim,
            startedAt,
          });
        } else if (!message.interim) {
          // An empty final (the model heard nothing intelligible) must clear
          // any provisional line the interims put up.
          this.#onCaption(message.roomId, message.userId, {
            id: message.utteranceId,
            text: null,
            final: true,
            startedAt,
          });
        }
        break;
      }
      case "job-error":
        // A single bad utterance isn't fatal; keep going but surface it.
        // eslint-disable-next-line no-console
        console.warn("[voice] subtitles transcription error", message);
        break;
    }
  }

  #live(tap, epoch) {
    return epoch === this.#epoch && this.#enabled;
  }

  #handleSpeechStart(tap, epoch) {
    if (!this.#live(tap, epoch)) {
      return;
    }
    tap.speaking = true;
    tap.utteranceId = ++this.#utteranceCounter;
    this.#noteUtteranceStart(tap.utteranceId);
    tap.frames = [];
    tap.bufferedSamples = 0;
    tap.samplesSinceInterim = 0;
    tap.interimSent = false;
  }

  // Fires for every VAD frame; only frames inside an utterance are kept, and
  // once enough new audio accumulates the snapshot-so-far is transcribed as
  // a provisional caption.
  #handleFrame(tap, epoch, frame) {
    if (!this.#live(tap, epoch) || !tap.speaking) {
      return;
    }

    // Under sustained transcription backlog the provisional passes are shed
    // entirely; the final (speech-end) pass still covers the utterance.
    if (this.#interimsSuspended) {
      tap.frames = [];
      tap.bufferedSamples = 0;
      tap.samplesSinceInterim = 0;
      return;
    }

    tap.frames.push(frame.slice());
    tap.bufferedSamples += frame.length;
    tap.samplesSinceInterim += frame.length;

    while (
      tap.bufferedSamples > INTERIM_WINDOW_MAX_SAMPLES &&
      tap.frames.length > 1
    ) {
      tap.bufferedSamples -= tap.frames.shift().length;
    }

    if (
      tap.bufferedSamples >= INTERIM_MIN_SAMPLES &&
      tap.samplesSinceInterim >= INTERIM_INTERVAL_SAMPLES
    ) {
      tap.samplesSinceInterim = 0;

      const snapshot = new Float32Array(tap.bufferedSamples);
      let offset = 0;
      for (const chunk of tap.frames) {
        snapshot.set(chunk, offset);
        offset += chunk.length;
      }
      if (this.#postTranscribe(tap, snapshot, true)) {
        tap.interimSent = true;
      }
    }
  }

  #handleUtterance(tap, epoch, audio) {
    if (!this.#live(tap, epoch)) {
      return;
    }
    tap.speaking = false;
    tap.frames = [];
    tap.bufferedSamples = 0;
    if (!tap.utteranceId) {
      tap.utteranceId = ++this.#utteranceCounter;
      this.#noteUtteranceStart(tap.utteranceId);
    }
    this.#postTranscribe(tap, audio, false);
  }

  // Too short to be speech after all: withdraw any provisional line and make
  // sure an in-flight interim result can't resurrect it.
  #handleMisfire(tap, epoch) {
    tap.speaking = false;
    tap.frames = [];
    tap.bufferedSamples = 0;
    this.#utteranceStarts.delete(tap.utteranceId);

    if (!this.#live(tap, epoch) || !tap.interimSent) {
      return;
    }
    tap.interimSent = false;
    this.#retracted.add(tap.utteranceId);
    if (this.#retracted.size > 200) {
      this.#retracted.clear();
    }
    this.#onCaption(tap.roomId, tap.userId, {
      id: tap.utteranceId,
      text: null,
      final: true,
    });
  }

  #postTranscribe(tap, audio, interim) {
    if (!this.#enabled || !this.#worker || !this.#workerReady) {
      return false;
    }

    // Respect the view bounds: the audio may be a window into a larger
    // buffer, and slice(0) of the raw buffer would ship the wrong bytes.
    const pcm = audio.buffer.slice(
      audio.byteOffset,
      audio.byteOffset + audio.byteLength
    );
    this.#worker.postMessage(
      {
        type: "transcribe",
        jobId: ++this.#jobCounter,
        roomId: tap.roomId,
        userId: tap.userId,
        utteranceId: tap.utteranceId,
        interim,
        pcm,
        // Stamped here (not in the worker) because heavy jobs block the
        // worker's event loop, delaying its onmessage arbitrarily.
        sentAt: Date.now(),
      },
      [pcm]
    );
    return true;
  }

  #failWorker(error) {
    this.#terminateWorker();
    this.#onError(error);
  }

  #terminateWorker() {
    clearTimeout(this.#readyTimer);
    this.#readyTimer = null;
    if (this.#worker) {
      this.#worker.terminate();
      this.#worker = null;
    }
    this.#workerReady = false;
    this.#interimsSuspended = false;
  }

  // Entries are removed when the final caption (or a misfire) lands; the cap
  // only guards against utterances whose results never arrive at all.
  #noteUtteranceStart(utteranceId) {
    if (this.#utteranceStarts.size > 200) {
      this.#utteranceStarts.clear();
    }
    this.#utteranceStarts.set(utteranceId, Date.now());
  }

  #key(roomId, userId) {
    return `${roomId}:${userId}`;
  }

  #removeTap(key) {
    const tap = this.#taps.get(key);
    if (!tap) {
      return;
    }

    this.#taps.delete(key);
    if (tap.vad) {
      this.#teardownVad(tap.vad);
    }
    // Discard whatever this speaker still has waiting in the transcription
    // queue; a detached tap's captions would be dropped on arrival anyway,
    // so transcribing them is pure backlog.
    this.#worker?.postMessage({
      type: "flush",
      roomId: tap.roomId,
      userId: tap.userId,
    });
    this.#onLoadingChange();
  }

  #teardownVad(vad) {
    try {
      vad.destroy();
    } catch {
      // ignore
    }
  }
}
